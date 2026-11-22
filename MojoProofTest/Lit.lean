import MojoProofTest.SymPhi

/-!
# Float literals evaluated by the kernel

`floatLit` (MojoProof/Sem/Eval.lean) reads a decimal literal's digits with `digits`, which the
kernel reduces, and rounds the literal's rational value once to its type with FloatLib's
`Model.ofRat`, so every value below is computed by `decide +kernel`. Each result covers the
literals it names, not all literals.

* `naive_zero`: the only float literal among the `phi` operands of the naive matmul kernel
  (`naive`, MojoProofTest/SymPhi.lean) is `0.000000e+00` (`%48`'s value from `%45`), which the
  lexer reads as `.dec false "0" "000000" 0`; at `float` it is `+0`.
* `dec_hex`: `0.0`, `1.5` and `-1.5e+01` at each of `half`, `bfloat`, `float` and `double`, and
  `0.1` at `double`, have the values of their hexadecimal forms (`0x0`, `0x3FF8000000000000`,
  `0xC02E000000000000`, `0x3FB999999999999A`), and each is a value.
* `tenth`: `0.1` at `float` is `0x3DCCCCCD` and has the value of `0x3FB99999A0000000` (the
  `double` bits of that `float`), at `half` that of `0xH2E66`, at `bfloat` that of `0xR3DCD`.
* `once`: `1.0000000596046447753906250000000001` at `float` is `0x3F800001`: it lies just above
  the midpoint `1 + 2 ^ -24` of `1` and the next `float`. Rounded first to `double` it is that
  midpoint, which then rounds to `1` (`0x3F800000`, ties to even): two roundings give another
  value.
* `range`: at `float`, `3.4028235e38` is the largest finite value `0x7F7FFFFF`, `8e-46` and `1e-45`
  are the least subnormal `0x00000001`, and `-0.0` is `-0` (`0x80000000`); at `half`, `65519.0`
  is the largest finite value `0x7BFF`.
* `dec_faults`: `floatLit` faults on literals whose rounding overflows (`3.4028236e38` and `1e39`
  at `float`, `65520.0` at `half`), on nonzero literals whose rounding is zero (`7e-46` and
  `1e-50` at `float`), on digits with `_` (`1_0.5`, `1._`) and on the malformed `1.x` and the
  literal with no digits.
* `agree`, `refused`: the earlier reading of decimal literals (`old`: round to `double`, then
  require the value to be exact in the type) and `floatLit`. On the 21 literals of `lits` at each
  of the four types, wherever `old` gives a value `floatLit` gives the same one (61 of the 84
  pairs); `floatLit` gives a value on 77 of them. `1e400` and `1e-400`, which `old` reads as
  `+inf` and `+0` at every type, `floatLit` refuses.
* `toNat_inst`, instances of `digits_toList`: core's `String.toNat?` reads `000000` as 0 and
  `1234` as 1234 and refuses the empty string, by evaluating `digits` (the kernel does not reduce
  `String.toNat?`); `digits` refuses `1_000`, `_1` and `1__0`.
-/

namespace MojoProofTest.Lit

open MojoProof.Sem MojoProof.LLVM FloatLib.Floats.Formats.BinaryInterchange

/-- The FloatLib value of the result `r` of reading a literal at float type `t`: the scalar read
back as a float of `t`, or `none` when `r` is a fault. -/
def valOf (t : FloatTy) (r : Except Fault Val) : Option (Model t.fmt) :=
  r.toOption.bind (·.float? t)

/-- The FloatLib value of literal `lit` at float type `t`: `floatLit`'s scalar read back as a
float of `t`, or `none` when `floatLit` faults. -/
def litVal (t : FloatTy) (lit : FloatLit) : Option (Model t.fmt) :=
  valOf t (floatLit t lit)

/-- The bits of literal `lit`'s value at float type `t` (`litVal`), or `none` when `floatLit`
faults. -/
def bitsOf (t : FloatTy) (lit : FloatLit) : Option Nat :=
  (litVal t lit).map Model.toNatBits

/-- Literals `lit` and `lit'` have one value at float type `t`, and `lit` has a value there. -/
def same (t : FloatTy) (lit lit' : FloatLit) : Bool :=
  (litVal t lit).isSome && litVal t lit == litVal t lit'

/-- The float literals among the incoming values of the `phi`s of block `b`, in order. -/
def phiLits (b : MojoProof.LLVM.Block) : List FloatLit :=
  b.stmts.toList.flatMap fun s => match s.inst with
    | .phi _ inc => inc.filterMap fun (v, _) => match v with
      | .float lit => some lit
      | _ => none
    | _ => []

/-- The naive matmul kernel's `phi` operands have one float literal, `0.000000e+00` (`%48`'s
value from `%45`, read as `.dec false "0" "000000" 0`), and at `float` it is `+0`, by
`decide +kernel`. -/
theorem naive_zero :
    SymPhi.naive.fn_0.blocks.toList.flatMap phiLits = [FloatLit.dec false "0" "000000" 0] ∧
      litVal .float (.dec false "0" "000000" 0) =
        (some (Model.zero .binary32 false) : Option (Model FloatTy.float.fmt)) := by
  decide +kernel

/-- `0.0`, `1.5` and `-1.5e+01` at each of `half`, `bfloat`, `float` and `double`, and `0.1` at
`double`, have the values of their hexadecimal (`double` bits) forms, and each is a value, by
`decide +kernel`. -/
theorem dec_hex :
    [FloatTy.half, .bfloat, .float, .double].all (fun t =>
        same t (.dec false "0" "0" 0) (.hex "" 0) &&
        same t (.dec false "1" "5" 0) (.hex "" 0x3FF8000000000000) &&
        same t (.dec true "1" "5" 1) (.hex "" 0xC02E000000000000)) ∧
      same .double (.dec false "0" "1" 0) (.hex "" 0x3FB999999999999A) := by
  decide +kernel

/-- `0.1` rounded once to each 16- and 32-bit type: at `float` its bits are `0x3DCCCCCD` and it has
the value of the `0x` literal `0x3FB99999A0000000`, at `half` that of `0xH2E66` and at `bfloat`
that of `0xR3DCD`, by `decide +kernel`. -/
theorem tenth :
    bitsOf .float (.dec false "0" "1" 0) = some 0x3DCCCCCD ∧
      same .float (.dec false "0" "1" 0) (.hex "" 0x3FB99999A0000000) ∧
      same .half (.dec false "0" "1" 0) (.hex "H" 0x2E66) ∧
      same .bfloat (.dec false "0" "1" 0) (.hex "R" 0x3DCD) := by
  decide +kernel

/-- **One rounding, not two.** `1.0000000596046447753906250000000001` (`1 + 2 ^ -24 + 10 ^ -34`)
at `float` has bits `0x3F800001`, while its rational rounded to `double` (FloatLib's
`Model.ofRat .binary64`) and then to `float` (`Model.cast`) has bits `0x3F800000` (`1`), by
`decide +kernel`. -/
theorem once :
    bitsOf .float (.dec false "1" "0000000596046447753906250000000001" 0) = some 0x3F800001 ∧
      (Model.cast .binary64 .binary32
        (Model.ofRat .binary64 ((10000000596046447753906250000000001 : Rat) / 10 ^ 34))).toNatBits =
        0x3F800000 := by
  decide +kernel

/-- Values at the ends of the range, by `decide +kernel`: at `float`, `3.4028235e38` has bits
`0x7F7FFFFF` (the largest finite `float`), `8e-46` and `1e-45` have bits `1` (the least
subnormal, `2 ^ -149`), and `-0.0` has bits `0x80000000` (`-0`); at `half`, `65519.0` has bits
`0x7BFF` (the largest finite `half`, 65504). -/
theorem range :
    [(FloatTy.float, FloatLit.dec false "3" "4028235" 38, 0x7F7FFFFF),
      (.float, .dec false "8" "0" (-46), 1), (.float, .dec false "1" "0" (-45), 1),
      (.float, .dec true "0" "0" 0, 0x80000000), (.half, .dec false "65519" "0" 0, 0x7BFF)].all
      (fun (t, lit, b) => bitsOf t lit == some b) := by
  decide +kernel

/-- `floatLit` faults, by `decide +kernel`, on: `3.4028236e38` and `1e39` at `float` and
`65520.0` at `half` (the rounding is infinite); `7e-46` and `1e-50` at `float` (nonzero, and the
rounding is zero); `1_0.5` and `1._` at `float` (`digits` refuses `_`); and the malformed `1.x`
and the literal with no digits at `float`. -/
theorem dec_faults :
    [(FloatTy.float, FloatLit.dec false "3" "4028236" 38), (.float, .dec false "1" "0" 39),
      (.half, .dec false "65520" "0" 0), (.float, .dec false "7" "0" (-46)),
      (.float, .dec false "1" "0" (-50)), (.float, .dec false "1_0" "5" 0),
      (.float, .dec false "1" "_" 0), (.float, .dec false "1" "x" 0),
      (.float, .dec false "" "" 0)].all (fun (t, lit) => !(floatLit t lit).isOk) := by
  decide +kernel

/-- The earlier reading of a decimal literal, for comparison with `floatLit`: its rational
rounded to `double` (FloatLib's `Model.ofRat .binary64`), negated if the literal is, and then
the value at `t` only if converting it to `t` and back gives its bits (`floatLit.exactIn`);
other literals as `floatLit` reads them. -/
def old (t : FloatTy) (lit : FloatLit) : Except Fault Val :=
  match lit with
  | .dec neg i f e =>
    match digits (i.toList ++ f.toList) with
    | some d =>
      let x := Model.ofRat .binary64 ((d : Rat) * (10 : Rat) ^ (e - f.length))
      floatLit.exactIn t (if neg then Model.neg x else x)
    | none => throw (.unsupported "malformed float literal")
  | lit => floatLit t lit

/-- The 21 decimal literals of `agree`: `0.0`, `-0.0`, `1.5`, `-1.5e+01`, `0.1`, `0.5`, `0.25`,
`0.125`, `3.0`, `1e10`, `65504.0`, `6.103515625e-05` (`2 ^ -14`), `5.9604644775390625e-08`
(`2 ^ -24`), `3.4028234663852886e+38`, `1.1754943508222875e-38`, `1.401298464324817e-45`,
`9.999999`, `1.0000001`, `123.421`, `4.5e-13` and `-2.0`. -/
def lits : List FloatLit :=
  [.dec false "0" "0" 0, .dec true "0" "0" 0, .dec false "1" "5" 0, .dec true "1" "5" 1,
    .dec false "0" "1" 0, .dec false "0" "5" 0, .dec false "0" "25" 0, .dec false "0" "125" 0,
    .dec false "3" "0" 0, .dec false "1" "0" 10, .dec false "65504" "0" 0,
    .dec false "6" "103515625" (-5), .dec false "5" "9604644775390625" (-8),
    .dec false "3" "4028234663852886" 38, .dec false "1" "1754943508222875" (-38),
    .dec false "1" "401298464324817" (-45), .dec false "9" "999999" 0, .dec false "1" "0000001" 0,
    .dec false "123" "421" 0, .dec false "4" "5" (-13), .dec true "2" "0" 0]

/-- The four float types. -/
def tys : List FloatTy := [.half, .bfloat, .float, .double]

/-- **What the earlier reading and `floatLit` agree on, on 84 pairs.** For each of the 21
literals of `lits` at each of the four float types: if `old` gives a value, `floatLit` gives the
same value. `old` gives a value on 61 of the 84 pairs and `floatLit` on 77 (it also reads, among
others, `0.1` at `half`, `bfloat` and `float`). By `decide +kernel`. -/
theorem agree :
    (lits.all fun lit => tys.all fun t => match valOf t (old t lit) with
      | some x => litVal t lit == some x
      | none => true) ∧
      (lits.flatMap fun lit => tys.filter fun t => (valOf t (old t lit)).isSome).length = 61 ∧
      (lits.flatMap fun lit => tys.filter fun t => (litVal t lit).isSome).length = 77 := by
  decide +kernel

/-- **What `floatLit` refuses that the earlier reading read.** At each of the four float types,
`old` reads `1e400` (its `double` rounding is `+inf`) and `1e-400` (its `double` rounding is
`+0`), and `floatLit` faults on both; at `double`, `old`'s values have the bits of `+inf`
(`0x7FF0000000000000`) and of `+0`. By `decide +kernel`. -/
theorem refused :
    tys.all (fun t => (old t (.dec false "1" "0" 400)).isOk &&
        !(floatLit t (.dec false "1" "0" 400)).isOk &&
        (old t (.dec false "1" "0" (-400))).isOk &&
        !(floatLit t (.dec false "1" "0" (-400))).isOk) ∧
      (valOf .double (old .double (.dec false "1" "0" 400))).map Model.toNatBits =
        some 0x7FF0000000000000 ∧
      (valOf .double (old .double (.dec false "1" "0" (-400)))).map Model.toNatBits = some 0 := by
  decide +kernel

/-- Instances of `digits_toList`: core's `String.toNat?` reads `000000` as 0 and `1234` as 1234
and refuses the empty string, each by `digits_toList` and evaluating `digits` with
`decide +kernel`; and `digits` refuses `1_000`, `_1` and `1__0`, by `decide +kernel`. -/
theorem toNat_inst :
    "000000".toNat? = some 0 ∧ "1234".toNat? = some 1234 ∧ "".toNat? = none ∧
      digits "1_000".toList = none ∧ digits "_1".toList = none ∧ digits "1__0".toList = none :=
  ⟨(digits_toList "000000" (by decide +kernel)).symm.trans (by decide +kernel),
    (digits_toList "1234" (by decide +kernel)).symm.trans (by decide +kernel),
    (digits_toList "" (by decide +kernel)).symm.trans (by decide +kernel),
    by decide +kernel, by decide +kernel, by decide +kernel⟩

end MojoProofTest.Lit
