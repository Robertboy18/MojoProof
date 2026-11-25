import MojoProof.Sem.Thread
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.MixedError.Attribute
import FloatLib.Floats.Formats.BinaryInterchange.Algebraic.Rounding.DirectedEnclosureProof
import FloatLib.Floats.Formats.BinaryInterchange.Arithmetic.Finiteness

/-!
# The definitions of the grid's `mma` (docs/proofs/tensor-core.md)

The functions `Grid.fire` runs at a warp's `mma`, below the grid so that it can call them; the
statements about them are in `MojoProof.Sem.TensorCore` (the layouts and `mmaStep`),
`MojoProof.Sem.TensorCoreAcc` (the accumulation `fuseAcc`) and `MojoProof.Sem.TensorCoreWarp`
(the registers and `mmaWarp`).

Definitions:
* `Frag`, `Frag.scatter`, `Frag.gather`: a fragment layout, a tile into the registers and back;
  `fragA`, `fragB`, `fragC`: the PTX ISA's layouts of A, B and C/D (version 9.5, section
  9.7.16.5.14); `mmaFrags v`: the layouts of the importer's `Mma` value `v`;
  `mmaStep`: the D registers with the accumulation a parameter.
* `RegForm` with `pack`, `width`, `get`, `put`, `ok`, `elem`: how a register holds its elements
  as bit patterns; `abForm`, `accForm`: the forms of `mma`'s operands; `argElem`, `argsOk`: the
  elements of an operand in the lanes' arguments; `mmaWarp v acc x`: the warp's `mma` with the
  accumulation `acc` on bit patterns.
* `expAt`, `truncAt`, `topExp`, `fuseSum`, `fuseRound`, `prodAddend`, `fuseStep`, `fuseFold`,
  `fuseAcc fi fc n p`: a fused, truncating block accumulation.
* `MmaAcc`: an accumulation policy, a function of the formats, the input pairs and C, which the
  ISA leaves open; `gridAcc`, the measured policy `fuseAcc fi fc 8 24` and the launches'
  default; `MmaAcc.bits`, a policy on bit patterns.
* `gridFmt`, `wordFinite`, `allFinite`, `mmaGrid A v x`: the grid's `mma` with the policy `A`,
  `mmaWarp` with `A.bits fi` on bf16 and f16 inputs with an f32 accumulator, when every element
  decodes to a finite word.

Proved: `mmaGrid_agg` (every lane's result is an aggregate of words, for every policy and `Mma`
value).
-/

namespace MojoProof.Sem

open FloatLib FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange LLVM

/-- A fragment layout of a tile in a warp's registers: each of the 32 lanes holds `regs` registers
(32-bit, and 64-bit for f64) of `pack` elements each; `pos l r s` is the tile cell
`(row, column)` of element `s` (element 0 in the low bits) of register `r` of lane `l`, and
`own i j` the `(lane, register, element)` meant to hold cell `(i, j)`. -/
structure Frag where
  /-- Builds a layout from its sizes and maps. -/
  mk ::
  /-- The number of rows of the tile. -/
  rows : Nat
  /-- The number of columns of the tile. -/
  cols : Nat
  /-- The number of registers per lane. -/
  regs : Nat
  /-- The number of elements per register. -/
  pack : Nat
  /-- The cell of element `s` of register `r` of lane `l`. -/
  pos : Nat → Nat → Nat → Nat × Nat
  /-- The lane, register and element of cell `(i, j)`. -/
  own : Nat → Nat → Nat × Nat × Nat

namespace Frag

/-- The registers holding the tile `T` in layout `F`: element `s` of register `r` of lane `l` is
`T` at the cell `F.pos l r s`. -/
def scatter {α : Type} (F : Frag) (T : Nat → Nat → α) (l r s : Nat) : α :=
  T (F.pos l r s).1 (F.pos l r s).2

/-- The tile the registers `x` hold in layout `F`: cell `(i, j)` is `x` at the lane, register
and element `F.own i j`. -/
def gather {α : Type} (F : Frag) (x : Nat → Nat → Nat → α) (i j : Nat) : α :=
  x (F.own i j).1 (F.own i j).2.1 (F.own i j).2.2

end Frag

/-- The A operand of `mma.m<8h>n8k<4pc>` (PTX ISA 9.5, section 9.7.16.5.14), row major, with
`p` elements per register: an `8h × 4pc` tile in `hc` registers per lane; element `s` of
register `r` of lane `l` is cell `(l / 4 + 8 (r % h), s + p (l % 4 + 4 (r / h)))`. -/
def fragA (h p c : Nat) : Frag where
  rows := 8 * h
  cols := 4 * p * c
  regs := h * c
  pack := p
  pos l r s := (l / 4 + 8 * (r % h), s + p * (l % 4 + 4 * (r / h)))
  own i j := (4 * (i % 8) + j / p % 4, i / 8 + h * (j / p / 4), j % p)

/-- The B operand of `mma.m16n8k<4pc>` (PTX ISA 9.5, section 9.7.16.5.14), column major, with
`p` elements per register: a `4pc × 8` tile in `c` registers per lane; element `s` of register
`r` of lane `l` is cell `(s + p (l % 4 + 4 r), l / 4)`. -/
def fragB (p c : Nat) : Frag where
  rows := 4 * p * c
  cols := 8
  regs := c
  pack := p
  pos l r s := (s + p * (l % 4 + 4 * r), l / 4)
  own i j := (4 * j + i / p % 4, i / p / 4, i % p)

/-- The C and D operands of `mma.m<8h>n8k<k>` (PTX ISA 9.5, section 9.7.16.5.14), for every
`k`, with `p` accumulators per register (1 for f32 and f64, 2 for f16): an `8h × 8` tile in
`2h / p` registers per lane; element `s` of register `r` of lane `l`, the accumulator
`i = p r + s`, is cell `(l / 4 + 8 (i / 2), 2 (l % 4) + i % 2)`. -/
def fragC (h p : Nat) : Frag where
  rows := 8 * h
  cols := 8
  regs := 2 * h / p
  pack := p
  pos l r s := (l / 4 + 8 * ((p * r + s) / 2), 2 * (l % 4) + (p * r + s) % 2)
  own i j := (4 * (i % 8) + j / 2, (2 * (i / 8) + j % 2) / p, (2 * (i / 8) + j % 2) % p)

/-- How a register holds its elements as bit patterns: `word w`, one `w`-bit element, the
scalar `Val.bits w`; `pair`, two 16-bit elements in a 32-bit word `Val.bits 32`, element 0 in
the low bits; `vec2`, two 16-bit elements, the lanes of a `<2 x half>` vector `Val.vec`. -/
inductive RegForm
  /-- One element of `w` bits, the scalar `Val.bits w`. -/
  | word (w : Nat)
  /-- Two 16-bit elements in a 32-bit word, element 0 in the low 16 bits. -/
  | pair
  /-- Two 16-bit elements, the two lanes of a vector of 16-bit scalars. -/
  | vec2
  deriving DecidableEq, Repr

namespace RegForm

/-- The number of elements in a register of the form: 1 for `word`, 2 for `pair` and `vec2`. -/
def pack : RegForm → Nat
  | .word _ => 1 | .pair => 2 | .vec2 => 2

/-- The width in bits of an element of the form: `w` for `word w`, 16 for `pair` and `vec2`. -/
def width : RegForm → Nat
  | .word w => w | .pair => 16 | .vec2 => 16

/-- Element `s` of the register `v` in the form `f`, as a number below `2 ^ f.width`: for
`word w`, the word of `Val.bits w` (`s = 0`); for `pair`, bits `16 s` to `16 s + 15` of
`Val.bits 32` (`s < 2`); for `vec2`, lane `s` of a vector of two `Val.bits 16` (`s < 2`).
`none` for an element past `pack`, and for a value not of the form: poison, `undef`, a pointer,
an aggregate, another width or another number of lanes. -/
def get (f : RegForm) (v : Val) (s : Nat) : Option Nat :=
  match f, v with
  | .word w, .bits n b => if n = w ∧ s = 0 then some b.toNat else none
  | .pair, .bits n b => if n = 32 ∧ s < 2 then some (b.toNat / 2 ^ (16 * s) % 2 ^ 16) else none
  | .vec2, .vec [.bits n x, .bits m y] =>
    if n = 16 ∧ m = 16 ∧ s < 2 then some (if s = 0 then x.toNat else y.toNat) else none
  | _, _ => none

/-- The register of the form `f` holding the elements `e 0`, …, `e (f.pack - 1)`, each taken
modulo `2 ^ f.width`. -/
def put : RegForm → (Nat → Nat) → Val
  | .word w, e => .bits w (BitVec.ofNat w (e 0))
  | .pair, e => .bits 32 (BitVec.ofNat 32 (e 0 % 2 ^ 16 + 2 ^ 16 * (e 1 % 2 ^ 16)))
  | .vec2, e => .vec [.bits 16 (BitVec.ofNat 16 (e 0)), .bits 16 (BitVec.ofNat 16 (e 1))]

/-- The register `v` is of the form `f`: each of its `f.pack` elements decodes (`get`). -/
def ok (f : RegForm) (v : Val) : Bool :=
  (List.range f.pack).all fun s => (f.get v s).isSome

/-- Element `s` of the register `v` in the form `f`, `0` when it does not decode. -/
def elem (f : RegForm) (v : Val) (s : Nat) : Nat :=
  (f.get v s).getD 0

end RegForm

/-- The register form of an `mma` input type, as `MmaTy.reg` types it: tf32 one element in an
`i32` (`word 32`), bf16 two in an `i32` (`pair`), f16 two in a `<2 x half>` (`vec2`), f64 one
`double` (`word 64`). -/
def abForm : MmaTy → RegForm
  | .tf32 => .word 32 | .bf16 => .pair | .f16 => .vec2 | .f64 => .word 64

/-- The register form of an `mma` accumulator of type `t`, the scalar `Ty.fp t`: one element of
the type's width, 16 bits for `half` and `bfloat`, 32 for `float`, 64 for `double`. -/
def accForm : FloatTy → RegForm
  | .half => .word 16 | .bfloat => .word 16 | .float => .word 32 | .double => .word 64

/-- The fragment layouts of the importer's `mma` value `v` (`Mma.ofName?`): the A, B and C/D
layouts `fragA (m / 8) p (k / 4p)`, `fragB p (k / 4p)` and `fragC (m / 8) 1`, with
`p = (abForm v.ab).pack` the elements per register of the input type (1 for tf32 and f64, 2 for
bf16 and f16), for every `v` of `Mma.table` (`Mma.ok`, the table the importer reads): the
shapes the PTX ISA lists for f16, tf32, bf16 and f64 inputs (`m16n8k8`, `m16n8k16` in f16 and
bf16, `m16n8k4`, `m16n8k8` in tf32, `m8n8k4` and `m16n8k<4, 8, 16>` in f64). `none` for every
other value, among them `m8n8k4` with f16 inputs, whose layouts are `quadA`, `quadB` and
`quadC`, four products of the quad pairs' own tiles, which `mmaStep` does not model (PTX ISA
9.5, section 9.7.16.5.1), and every `k` the ISA does not list, such as `m16n8k24`. -/
def mmaFrags (v : Mma) : Option (Frag × Frag × Frag) :=
  let p := (abForm v.ab).pack
  if v.ok then
    some (fragA (v.m / 8) p (v.k / (4 * p)), fragB p (v.k / (4 * p)), fragC (v.m / 8) 1)
  else none

/-- The D registers of `mma` with layouts `FA`, `FB`, `FC`, accumulation `acc` and the lanes'
A, B and C registers `a`, `b`, `c`: element `s` of register `r` of lane `l`, at the cell
`(i, j) = FC.pos l r s`, is `acc` of row `i` of the tile gathered from `a`, column `j` of the
tile gathered from `b`, and `C (i, j)` gathered from `c`. -/
def mmaStep {α β : Type} {K : Nat} (FA FB FC : Frag) (acc : (Fin K → α) → (Fin K → α) → β → β)
    (a b : Nat → Nat → Nat → α) (c : Nat → Nat → Nat → β) (l r s : Nat) : β :=
  acc (fun k => FA.gather a (FC.pos l r s).1 k) (fun k => FB.gather b k (FC.pos l r s).2)
    (FC.gather c (FC.pos l r s).1 (FC.pos l r s).2)

/-- Element `s` of register `r` of lane `l` of the operand that starts at position `off` of each
lane's arguments `x l`, in the form `f`: element `s` of argument `off + r`, `0` when it does
not decode or is missing. -/
def argElem (f : RegForm) (x : Nat → List Val) (off l r s : Nat) : Nat :=
  f.elem ((x l).getD (off + r) .poison) s

/-- The operand of `n` registers at position `off` of the 32 lanes' arguments `x` decodes: for
every lane `l < 32` and `r < n`, argument `off + r` of lane `l` is of the form `f`. -/
def argsOk (f : RegForm) (x : Nat → List Val) (off n : Nat) : Bool :=
  (List.range 32).all fun l => (List.range n).all fun r => f.ok ((x l).getD (off + r) .poison)

/-- The warp's `mma` of the importer's value `v` (`Mma.ofName?`) with the accumulation `acc` on
bit patterns, from the 32 lanes' arguments `x` (`x l`, lane `l`'s: its A registers, then its B
registers in the form `abForm v.ab`, then its C registers in the form `accForm v.cd`, as the
intrinsic's signature types them): lane `l`'s result is the aggregate of its D registers, element
`s` of register `r` the element `mmaStep` gives with the layouts `mmaFrags v` on the decoded
elements. `none` when `mmaFrags` rejects `v`, a lane does not pass `Mma.regs`' numbers of
registers, or a register does not decode. -/
def mmaWarp (v : Mma) (acc : (Fin v.k → Nat) → (Fin v.k → Nat) → Nat → Nat)
    (x : Nat → List Val) : Option (Nat → Val) :=
  match mmaFrags v with
  | some (FA, FB, FC) =>
    if ((List.range 32).all fun l => (x l).length == FA.regs + FB.regs + FC.regs) &&
        argsOk (abForm v.ab) x 0 FA.regs && argsOk (abForm v.ab) x FA.regs FB.regs &&
        argsOk (accForm v.cd) x (FA.regs + FB.regs) FC.regs then
      some fun l => .agg (List.ofFn fun r : Fin FC.regs => (accForm v.cd).put fun s =>
        mmaStep FA FB FC acc (argElem (abForm v.ab) x 0) (argElem (abForm v.ab) x FA.regs)
          (argElem (accForm v.cd) x (FA.regs + FB.regs)) l r s)
    else none
  | none => none

/-- The exponent an aligning adder gives the rational `x` of format `f`: `⌊log₂ |x|⌋`, raised to
`f`'s least normal exponent, so every subnormal has the least normal exponent. -/
def expAt (f : FloatFormat) (x : ℚ) : ℤ := max (Int.log 2 |x|) f.minNormalExponent

/-- `x` truncated toward zero to a multiple of `2 ^ e`, for every integer `e`. -/
def truncAt (e : ℤ) (x : ℚ) : ℚ :=
  ((if 0 ≤ x then ⌊x / 2 ^ e⌋ else ⌈x / 2 ^ e⌉ : ℤ) : ℚ) * 2 ^ e

/-- The largest exponent of a nonzero addend of `xs` (pairs of a value and its exponent);
`none` when every addend is zero. -/
def topExp (xs : List (ℚ × ℤ)) : Option ℤ := ((xs.filter (·.1 ≠ 0)).map (·.2)).max?

/-- One pass of the aligning adder over the addends `xs`, each a value and its exponent: the
exact sum of the values truncated toward zero to multiples of `2 ^ (E - p)`, `E = topExp xs`;
`0` when every addend is zero. -/
def fuseSum (p : ℕ) (xs : List (ℚ × ℤ)) : ℚ :=
  match topExp xs with
  | none => 0
  | some E => (xs.map fun x => truncAt (E - p) x.1).sum

/-- The adder's rounding of the rational `s` into the format `fc`: FloatLib's `roundRat` toward
zero when `|s|` is at most the largest finite magnitude `M`; `M` with `s`'s sign
(`maxFinite`) when `|s|` is beyond it and below `2^(emax + 1)`, `emax = fc.maxNormalExponent`;
and the infinity of `s`'s sign (`nativeOverflow`) otherwise. -/
def fuseRound (fc : FloatFormat) (s : ℚ) : Model fc :=
  if |s| ≤ (Model.posMaxFinite fc).toRat?.getD 0 then
    Model.AlgebraicRounding.roundRat fc .towardZero s
  else if |s| < 2 ^ (fc.maxNormalExponent + 1) then Model.maxFinite fc (decide (s < 0))
  else Model.nativeOverflow fc (decide (s < 0))

/-- The addend of an input pair `(x, y)` of format `fi`: the exact product of their values
(`toRat?`, `0` for a word that is not finite) and the sum of their exponents `expAt fi`. -/
def prodAddend {fi : FloatFormat} (q : Model fi × Model fi) : ℚ × ℤ :=
  ((q.1.toRat?.getD 0) * (q.2.toRat?.getD 0),
    expAt fi (q.1.toRat?.getD 0) + expAt fi (q.2.toRat?.getD 0))

/-- One pass of the adder over the block `ps` of input pairs of format `fi`, from the running
value `r` of format `fc` (with its exponent `expAt fc`): `fuseRound` of `fuseSum p`; `r` itself
when it is not finite. -/
def fuseStep {fi fc : FloatFormat} (p : ℕ) (r : Model fc) (ps : List (Model fi × Model fi)) :
    Model fc :=
  match r.toRat? with
  | none => r
  | some q => fuseRound fc (fuseSum p ((q, expAt fc q) :: ps.map prodAddend))

/-- `J` passes of the adder from `r`, each over the next `n` input pairs of `ps`. -/
def fuseFold {fi fc : FloatFormat} (n p : ℕ) : ℕ → Model fc → List (Model fi × Model fi) → Model fc
  | 0, r, _ => r
  | J + 1, r, ps => fuseFold n p J (fuseStep p r (ps.take n)) (ps.drop n)

/-- **The fused block accumulation**, for input format `fi`, accumulator format `fc`, block
size `n` and `p` bits: the `K` pairs `(a k, b k)` in order, `n` to a block, folded from `c` by
`fuseStep p` in `⌈K / n⌉` passes. -/
def fuseAcc (fi fc : FloatFormat) (n p : ℕ) {K : ℕ} (a b : Fin K → Model fi) (c : Model fc) :
    Model fc :=
  fuseFold n p ((K + n - 1) / n) c (List.ofFn fun k => (a k, b k))

/-- The format of an `mma` input type whose accumulation the grid models: bfloat16 for `bf16`
and binary16 for `f16`; `none` for `tf32` (its internal layout is implementation defined) and
`f64`. -/
def gridFmt : MmaTy → Option FloatFormat
  | .bf16 => some .bfloat16 | .f16 => some .binary16 | _ => none

/-- The bit pattern `b` (taken modulo `2 ^ f.bitWidth`) is a finite word of format `f`: its
FloatLib value has a rational value (`toRat?`). -/
def wordFinite (f : FloatFormat) (b : Nat) : Bool :=
  (Model.ofBits (fmt := f) (BitVec.ofNat f.bitWidth b)).toRat?.isSome

/-- **An accumulation policy of `mma`**: for every input format `fi`, accumulator format `fc`
and number `K` of products, the D word from the `K` input pairs `(a k, b k)` and the C word
`c`. The PTX ISA leaves the order, the rounding and the handling of subnormal inputs of the
accumulation unspecified (version 9.5, section 9.7.16.5.14), so the grid's `mma` runs the
policy of its launch (`Launch.acc`) and every statement about the grid holds for every policy. -/
abbrev MmaAcc : Type :=
  (fi fc : FloatFormat) → {K : ℕ} → (Fin K → Model fi) → (Fin K → Model fi) → Model fc → Model fc

/-- **The measured policy**, the launches' default: `fuseAcc fi fc 8 24`, blocks of 8 products
with 24 bits below the largest addend's leading power, for every pair of formats. That a GPU
computes it is a measurement on one GPU, shape and input type (docs/TRUST.md T14). -/
def gridAcc : MmaAcc := fun fi fc => fuseAcc fi fc 8 24

/-- The policy `A` on bit patterns, for inputs of format `fi` and an f32 accumulator:
`A fi .binary32` on the words the patterns `a k`, `b k` (modulo `2 ^ fi.bitWidth`) and `c`
(modulo `2 ^ 32`) decode to, as the pattern of the binary32 result. -/
def MmaAcc.bits (A : MmaAcc) (fi : FloatFormat) {K : Nat} (a b : Fin K → Nat) (c : Nat) : Nat :=
  (A fi .binary32 (fun k => Model.ofBits (fmt := fi) (BitVec.ofNat fi.bitWidth (a k)))
    (fun k => Model.ofBits (fmt := fi) (BitVec.ofNat fi.bitWidth (b k)))
    (Model.ofBits (fmt := .binary32) (BitVec.ofNat 32 c))).toBits.toNat

/-- Every element `e l r s` of the 32 lanes' registers in the layout `F` is a finite word of
format `f` (`wordFinite`). -/
def allFinite (f : FloatFormat) (F : Frag) (e : Nat → Nat → Nat → Nat) : Bool :=
  (List.range 32).all fun l => (List.range F.regs).all fun r =>
    (List.range F.pack).all fun s => wordFinite f (e l r s)

/-- The grid's `mma` of the importer's value `v` with the accumulation policy `A` on the 32
lanes' arguments `x`: `mmaWarp v` with the accumulation `A.bits fi`, for inputs of a format
`fi` that `gridFmt` gives (bf16 and f16) and an f32 accumulator, when every element of A, B and
C is a finite word (`allFinite`); `none` for every other `Mma` value and on other arguments. -/
def mmaGrid (A : MmaAcc) (v : Mma) (x : Nat → List Val) : Option (Nat → Val) :=
  match gridFmt v.ab, mmaFrags v with
  | some fi, some (FA, FB, FC) =>
    if v.cd = FloatTy.float ∧ allFinite fi FA (argElem (abForm v.ab) x 0) = true ∧
        allFinite fi FB (argElem (abForm v.ab) x FA.regs) = true ∧
        allFinite .binary32 FC (argElem (accForm v.cd) x (FA.regs + FB.regs)) = true then
      mmaWarp v (A.bits fi) x
    else none
  | _, _ => none

/-- **The grid's `mma` results are aggregates of words**, for every policy, `Mma` value and
arguments: when `mmaGrid A v x` gives `y`, every lane's result `y l` is an aggregate of scalars
`Val.bits`. -/
theorem mmaGrid_agg {A : MmaAcc} {v : Mma} {x : Nat → List Val} {y : Nat → Val}
    (h : mmaGrid A v x = some y) (l : Nat) :
    ∃ rs : List Val, y l = .agg rs ∧ ∀ r ∈ rs, ∃ w b, r = .bits w b := by
  have hw : ∀ c, ∃ w, accForm c = .word w := fun c => by cases c <;> exact ⟨_, rfl⟩
  unfold mmaGrid at h
  split at h
  · split_ifs at h
    unfold mmaWarp at h
    split at h
    · split_ifs at h
      cases h
      refine ⟨_, rfl, fun r hr => ?_⟩
      rw [List.mem_ofFn] at hr
      obtain ⟨i, rfl⟩ := hr
      obtain ⟨w, e⟩ := hw v.cd
      rw [e]
      exact ⟨w, _, rfl⟩
    · cases h
  · cases h

end MojoProof.Sem
