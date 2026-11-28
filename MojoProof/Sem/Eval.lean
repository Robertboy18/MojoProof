import MojoProof.Sem.Op

/-!
# Operands and value instructions

Evaluation of operands (registers, globals, constants and constant expressions) and the
instructions that compute a value without changing memory: `getelementptr`, the casts, `icmp`,
`fcmp`, `select` and the aggregate and vector instructions. Vector operations apply the scalar
ones of `MojoProof.Sem.Op` lane by lane; lane `i` gets the oracle number `ch i` of the step.

* `getelementptr` (`gep`): indices are sign-extended or truncated to the index width of the base's
  address space, which is its pointer size (`Layout.parse` refuses other layouts); the offset is
  the sum of index times allocation size (struct fields: the field offset), wrapped to the index
  width. Under `nusw` (implied by `inbounds`) the result is poison if a truncation changes an
  index's signed value, or a term, a partial sum or the address plus a partial sum leaves the
  signed (sums: unsigned address) range; under `nuw` if a truncation changes an index's unsigned
  value, or, with each index read as an unsigned number of the index width (a narrower index
  sign-extended first, so `-1` is `2 ^ width - 1`), a term, a partial sum or the address plus a
  partial sum reaches `2 ^ width` (so an index into a zero-sized type never makes it poison);
  under `inbounds` with a nonzero index, if the base offset or the offset after a partial sum lies
  outside `[0, size]` of the base's block (LangRef, "getelementptr": `trunc nsw`/`trunc nuw`,
  `mul nsw`/`mul nuw`, `add nsw`/`add nuw`).
* A cast in a constant expression is one LangRef admits there (`CastOp.const`; LangRef, "Constant
  Expressions"); the others are unsupported. So evaluating an operand reads no oracle number.
* Pointer comparisons and `ptrtoint` read addresses (`Mem.addr`); `addrspacecast` keeps the block
  and offset, except that a cast of a null-based pointer is unsupported (LangRef does not fix its
  address). `fptoui`, `fptosi` and `inttoptr` are unsupported.
* A float literal is read as LangRef's "Simple Constants" says: a decimal literal is its exact
  rational value rounded once to the operand's type, to nearest with ties to even (FloatLib's
  `Model.ofRat`), and is refused if the rounding overflows to infinity or a nonzero value
  underflows to zero (`-0.0` is `-0`); a `0x` literal is the bits of a `double` and must convert
  exactly to the operand's type; `0xH` and `0xR` are the bits of a `half` and a `bfloat`. A
  decimal literal's digits are read by `digits`, a structural parse of the characters `0`-`9`
  (no `_`) that the kernel reduces, so `decide +kernel` can evaluate a decimal literal.

The module defines functions; it proves that `digits` reads every string of the characters
`0`-`9` as core's `String.toNat?` does (`digits_toList`), so `floatLit`'s decimal case on such
digits has the value of its `String.toNat?` reading (`floatLit_dec`); and, for every layout,
lane count `n`, lane width `w` and `n * w`-bit word, that `bitcast` to `<n x iw>` gives the
word's slices, low first (`castV_split`), and `bitcast` of them back gives the word
(`castV_join`; at `<2 x i32>` and `i64`, `castV_halves`). `fill`, the `poison` or `undef` value
of a type, is by structural recursion, so the kernel reduces it too; `fillAll_eq`: its struct
case is `fill` on each field.
-/

namespace MojoProof.Sem

open FloatLib.Floats.Formats.BinaryInterchange LLVM

/-- The element type of a vector type; any other type itself. -/
def _root_.MojoProof.LLVM.Ty.elt : Ty → Ty
  | .vec _ t => t
  | t => t

mutual
  /-- The value of type `t` all of whose scalars are `x` (`poison` or `undef`). By structural
  recursion on `t`, with `fillAll` on the fields of a struct, so the kernel evaluates it
  (well-founded recursion would not unfold under `decide +kernel`). -/
  def fill (x : Val) : Ty → Val
    | .vec n _ => .vec (List.replicate n x)
    | .arr n t => .agg (List.replicate n (fill x t))
    | .struct fs => .agg (fillAll x fs)
    | _ => x
  termination_by structural t => t

  /-- `fill x` at each of the types `fs`. By structural recursion on `fs`. -/
  def fillAll (x : Val) : List Ty → List Val
    | [] => []
    | t :: ts => fill x t :: fillAll x ts
  termination_by structural fs => fs
end

/-- `fillAll x` is `fill x` mapped over the types, for every value and list of types. -/
theorem fillAll_eq (x : Val) : ∀ fs : List Ty, fillAll x fs = fs.map (fill x)
  | [] => rfl
  | t :: ts => congrArg (fill x t :: ·) (fillAll_eq x ts)

mutual
  /-- No scalar of the value is `poison` or `undef` (LangRef's `noundef`). -/
  def Val.defined : Val → Bool
    | .poison | .undef => false
    | .vec xs | .agg xs => Val.allDefined xs
    | _ => true

  /-- No scalar of the values is `poison` or `undef`. -/
  def Val.allDefined : List Val → Bool
    | [] => true
    | x :: xs => x.defined && Val.allDefined xs
end

/-- Lane `i` of a vector; a scalar is its own lane. -/
def Val.lane (v : Val) (i : Nat) : Val :=
  match v with
  | .vec xs => xs.getD i .poison
  | v => v

/-- `f` on the lanes of a vector (with the lane number), on a scalar directly. -/
def lanes (f : Nat → Val → Except Fault Val) : Val → Except Fault Val
  | .vec xs => .vec <$> xs.zipIdx.mapM fun (x, i) => f i x
  | x => f 0 x

/-- `f` on the pairs of lanes of two vectors of one length, on scalars directly. -/
def lanes2 (f : Nat → Val → Val → Except Fault Val) : Val → Val → Except Fault Val
  | .vec xs, .vec ys =>
    if xs.length = ys.length then .vec <$> (xs.zip ys).zipIdx.mapM fun ((x, y), i) => f i x y
    else throw (.unsupported "vector operands of different lengths")
  | x, y => f 0 x y

/-- `f` on two scalars with LLVM's propagation: using `undef` is unsupported, and otherwise a
`poison` operand gives poison. -/
def strict2 (f : Val → Val → Except Fault Val) : Val → Val → Except Fault Val
  | .undef, _ | _, .undef => throw (.unsupported "use of undef")
  | .poison, _ | _, .poison => pure .poison
  | x, y => f x y

/-- `f` on the FloatLib values of two scalars of float type `t`, propagating as `strict2`. -/
def floats2 (t : FloatTy) (f : Model t.fmt → Model t.fmt → Val) : Val → Val → Except Fault Val :=
  strict2 fun x y => match x.float? t, y.float? t with
    | some a, some b => pure (f a b)
    | _, _ => throw (.unsupported "float operand of the wrong type")

/-- The natural number that the characters `cs` spell in decimal: `cs` is nonempty and every
character is one of `0`-`9`; otherwise `none`. LLVM's decimal float syntax has no digit
separator, so `_` is refused (core's `String.toNat?` skips a `_` between two digits). Every
function it calls is structural, so the kernel reduces it; `digits_toList` proves it equal to
`String.toNat?` on every string of the characters `0`-`9`. -/
def digits (cs : List Char) : Option Nat :=
  if cs ≠ [] ∧ cs.all Char.isDigit then some (Nat.ofDigitChars 10 cs 0) else none

/-- The value of float literal `lit` at float type `t`, as LLVM's assembler reads it (LangRef,
"Simple Constants"): a decimal literal `[-]i.f[e<exp>]` is the rational `i.f · 10 ^ exp` rounded
once to `t` (`near`: FloatLib's `Model.ofRat`, nearest with ties to even), and faults if the
rounding overflows to infinity or a nonzero literal underflows to zero; a `0x` literal (LLVM's
legacy form, sixteen hexadecimal digits) is the bits of a `double` and faults unless it converts
exactly to `t` (`exactIn`); `0xH` and `0xR` are the bits of a `half` and a `bfloat`; an `f0x`
literal is the bits of a value of `t` itself, and faults unless its digits are `t`'s width
divided by four. -/
def floatLit (t : FloatTy) (lit : FloatLit) : Except Fault Val :=
  match lit with
  | .hex "H" b => if t = .half then pure (.bits 16 (BitVec.ofNat 16 b)) else wrong
  | .hex "R" b => if t = .bfloat then pure (.bits 16 (BitVec.ofNat 16 b)) else wrong
  | .hex "" b => exactIn (Model.ofNatBits b)
  | .bits n b =>
    if 4 * n = t.fmt.bitWidth then pure (.bits t.fmt.bitWidth (BitVec.ofNat _ b))
    else throw (.unsupported "f0x float literal with another width than its type")
  | .dec neg i f e =>
    match digits (i.toList ++ f.toList) with
    | some d => near neg ((d : Rat) * (10 : Rat) ^ (e - f.length))
    | none => throw (.unsupported "malformed float literal")
  | .hex _ _ => wrong
where
  /-- The fault for a literal of another float type. -/
  wrong : Except Fault Val := throw (.unsupported "float literal of another type")
  /-- The binary64 value `x` at type `t` if converting it to `t` and back gives `x`'s bits, else
  a fault. -/
  exactIn (x : Model FloatFormat.binary64) : Except Fault Val :=
    let y := Model.cast .binary64 t.fmt x
    if (Model.cast t.fmt .binary64 y).toNatBits = x.toNatBits then pure (.ofFloat t y)
    else throw (.unsupported "float literal not exact in its type")
  /-- The rational `q` rounded once to `t` by FloatLib's `Model.ofRat t.fmt q` (to nearest, ties
  to even; FloatLib's `Model.toReal_ofRat_eq_roundAt` gives its real value when it is finite),
  then negated if `neg` (so `-0.0` is `-0`); a fault if the rounding is infinite (overflow) or
  `q` is nonzero and the rounding is zero (underflow). -/
  near (neg : Bool) (q : Rat) : Except Fault Val :=
    let x := Model.ofRat t.fmt q
    if x.isInfinite then throw (.unsupported "decimal float literal overflows its type")
    else if q ≠ 0 ∧ x.isZero then throw (.unsupported "decimal float literal underflows to zero")
    else pure (.ofFloat t (if neg then Model.neg x else x))

/-- For every string `s` of the characters `0`-`9`, `digits` of its characters is core's
`String.toNat? s`: both are `none` on the empty string, and otherwise core reads the digits with
its `_` filter, which removes nothing (core's `String.isNat_of_isDigit` and
`String.toNat?_eq_some_ofDigitChars`). On strings with a `_` they differ: `digits` refuses
`1_000`, which core reads as 1000. -/
theorem digits_toList (s : String) (h : s.toList.all Char.isDigit) :
    digits s.toList = s.toNat? := by
  have hd : ∀ c ∈ s.toList, c.isDigit := by simpa using h
  by_cases he : s = ""
  · subst he
    rw [String.toNat?_eq_none (Bool.eq_false_iff.2 fun h' => (String.isNat_iff.1 h').1 rfl)]
    rfl
  · rw [String.toNat?_eq_some_ofDigitChars (String.isNat_of_isDigit he hd), digits,
      ite_eq_left ⟨fun h' => he (String.toList_eq_nil_iff.1 h'), h⟩]
    congr
    refine (List.filter_eq_self.2 fun c hc => ?_).symm
    have := hd c hc
    rw [bne_iff_ne]
    rintro rfl
    exact absurd this (by decide)

/-- For every float type, sign, exponent and digit strings `i` and `f` of the characters
`0`-`9`, `floatLit`'s decimal case is its reading with core's `String.toNat?` on the digits
before and after the point. -/
theorem floatLit_dec (t : FloatTy) (neg : Bool) (i f : String) (e : Int)
    (h : (i ++ f).toList.all Char.isDigit) :
    floatLit t (.dec neg i f e) = match (i ++ f).toNat? with
      | some d => floatLit.near t neg ((d : Rat) * (10 : Rat) ^ (e - f.length))
      | none => throw (.unsupported "malformed float literal") := by
  rw [← digits_toList _ h, String.toList_append]
  rfl

/-- The steps of the indices `is` of a GEP with source type `src`, each index given as its value
`i` at the index width and, for an `i32` index, its own value `n` (unsigned; `none` for another
width): each index with the byte offset it adds and whether it selects a struct field. The first
index steps over `src`, each later one into the current type: array and vector elements by `i`
times the allocation size, struct fields by field `n` at its offset, converted to the index width
by `cv`; a struct index of another width than `i32` is refused (LangRef, "getelementptr",
Arguments: "When indexing into a (optionally packed) structure, only i32 integer constants are
allowed"; the importer refuses one that is not a constant, `Parser.gepStructOk`) (LangRef,
"getelementptr": "If the currently indexed type is a struct type, the struct offset
corresponding to the index is sign-extended or truncated to the pointer index type. Otherwise,
the index itself is sign-extended or truncated"). -/
def gepSteps (l : Layout) (cv : Int → Int) (src : Ty) :
    List (Int × Option Nat) → Except Fault (List (Int × Int × Bool))
  | [] => pure []
  | (i, _) :: is => do return (i, i * l.size src, false) :: (← into src is)
where
  /-- The steps of the later indices into type `t`: array and vector elements by allocation size,
  struct fields by field offset; a fault for a struct index out of range or not of type `i32`, or
  an index into a scalar type. -/
  into : Ty → List (Int × Option Nat) → Except Fault (List (Int × Int × Bool))
    | _, [] => pure []
    | .arr _ e, (i, _) :: is | .vec _ e, (i, _) :: is => do
      return (i, i * l.size e, false) :: (← into e is)
    | .struct fs, (_, some n) :: is =>
      if h : n < fs.length then do
        return (n, cv (l.fieldOffset 0 fs n), true) :: (← into (fs[n]'h) is)
      else throw (.unsupported "struct index out of range")
    | .struct _, (_, none) :: _ => throw (.unsupported "struct index not of type i32")
    | _, _ :: _ => throw (.unsupported "index into a scalar type")

/-- `getelementptr` with flags `fl` and source type `src` on pointer `p` of address space `a`, with
index values `idx` (scalars only). A struct index selects its field by its own value, and the
field's offset is converted to the index width (`gepSteps`); every other index is converted, and
`nusw` and `nuw` check that conversion (LangRef: "If the type of an index is larger than the
pointer index type, the truncation to the pointer index type preserves the signed value"), which
a struct index does not undergo. -/
def gepPtr (l : Layout) (m : Mem) (fl : GepFlags) (src : Ty) (a : Nat) (p : Ptr)
    (idx : List Val) : Except Fault Val := do
  let iw := (l.ptr a).1
  -- each index: its value at the index width and its own unsigned value, and whether the former
  -- is lossless in the signed and in the unsigned sense
  let some ix := idx.mapM (fun
      | .bits w b =>
        let i := if w ≤ iw then b.toInt else Int.bmod b.toInt (2 ^ iw)
        some (some ((i, if w = 32 then some b.toNat else none), i == b.toInt,
          decide (b.toNat < 2 ^ iw)))
      | .poison => some none
      | _ => none)
    | throw (.unsupported "GEP index that is not an integer scalar")
  let some ix := ix.mapM id | return .poison
  let steps ← gepSteps l (Int.bmod · (2 ^ iw)) src (ix.map (·.1))
  let terms := steps.map (·.2.1)
  let sums := (terms.scanl (· + ·) 0).tail
  let ad : Int := (← m.addr l a p)
  -- the converted indices (not a struct's) that lose their value
  let lossS := (ix.zip steps).any fun (x, st) => !st.2.2 && !x.2.1
  let lossU := (ix.zip steps).any fun (x, st) => !st.2.2 && !x.2.2
  let badS := lossS || (terms ++ sums).any (outS iw) ||
    sums.any fun s => ad + s < 0 || ad + s ≥ 2 ^ iw
  -- the unsigned reading (`nuw`): each index's value at the index width as an unsigned number
  -- and each struct offset so converted (the steps succeed, as the signed ones do: a struct
  -- index selects the same field in both)
  let usteps : Except Fault (List (Int × Int × Bool)) :=
    gepSteps l (· % 2 ^ iw) src (ix.map fun x => (x.1.1 % 2 ^ iw, x.1.2))
  let uterms : List Int := match usteps with
    | .ok us => us.map (·.2.1)
    | .error _ => [2 ^ iw]
  let usums := (uterms.scanl (· + ·) 0).tail
  let badU := lossU || (uterms ++ usums).any (· ≥ 2 ^ iw) ||
    usums.any fun s => ad + s ≥ 2 ^ iw
  let outside := match m.block p with
    | some b => (p.off :: sums.map (p.off + ·)).any fun o => o < 0 || o > b.size
    | none => true
  if (fl.nusw || fl.inbounds) && badS || fl.nuw && badU ||
      fl.inbounds && steps.any (·.1 != 0) && outside then
    return .poison
  return .ptr ⟨p.block, Int.bmod (p.off + sums.getLastD 0) (2 ^ iw)⟩

/-- `getelementptr` on a base value: poison gives poison. -/
def gep (l : Layout) (m : Mem) (fl : GepFlags) (src : Ty) (a : Nat) (idx : List Val) :
    Val → Except Fault Val
  | .ptr p => gepPtr l m fl src a p idx
  | .poison => pure .poison
  | .undef => throw (.unsupported "use of undef")
  | _ => throw (.unsupported "vector or non-pointer GEP base")

/-- A cast `op` of `x` from type `s` to type `t`; lane `i` of a float cast gets oracle number
`ch i`. -/
def castV (l : Layout) (m : Mem) (op : CastOp) (s : Ty) (x : Val) (t : Ty) (ch : Nat → Nat) :
    Except Fault Val :=
  match op, s.elt, t.elt with
  | .trunc, _, e | .zext, _, e | .sext, _, e => lanes (fun _ => intCast op (l.scalarBits e)) x
  | .fptrunc, .fp a, .fp b | .fpext, .fp a, .fp b => lanes (fun i v => floatCast a b v (ch i)) x
  | .sitofp, _, .fp b | .uitofp, _, .fp b => lanes (fun _ => intToFloat (op == .sitofp) b) x
  | .bitcast, _, _ => bitcast l s t x
  | .ptrtoint, .ptr a, e => lanes (fun _ v => match v with
      | .ptr p => do
        let w := l.scalarBits e
        return .bits w (BitVec.ofNat w (← m.addr l a p))
      | .poison => pure .poison
      | .undef => throw (.unsupported "use of undef")
      | _ => throw (.unsupported "ptrtoint of a non-pointer")) x
  | .addrspacecast, _, _ => lanes (fun _ v => match v with
      | .ptr p =>
        if p.block = 0 then throw (.unsupported "addrspacecast of a null-based pointer")
        else pure v
      | .poison => pure .poison
      | .undef => throw (.unsupported "use of undef")
      | _ => throw (.unsupported "addrspacecast of a non-pointer")) x
  | _, _, _ => throw (.unsupported "cast (fptoui, fptosi, inttoptr, or ill-typed)")

/-- **`bitcast` of a word to a vector gives its slices, low first**: for every layout `l`, memory
`m`, oracle numbers `ch`, lane count `n`, lane width `w` and `n * w`-bit word `x`, the `bitcast`
from `i(n * w)` to `<n x iw>` gives the vector whose lane `i` is bits `i * w` to `i * w + w - 1`
of `x` (`x.extractLsb' (i * w) w`). At `n = 2` and `w = 32`: `bitcast i64` to `<2 x i32>` gives
the low half, then the high half. -/
theorem castV_split (l : Layout) (m : Mem) (ch : Nat → Nat) {n w : Nat} (x : BitVec (n * w)) :
    castV l m .bitcast (.int (n * w)) (.bits (n * w) x) (.vec n (.int w)) ch =
      .ok (.vec ((List.range n).map fun i => .bits w (x.extractLsb' (i * w) w))) := by
  have hb : toBitList l (.int (n * w)) (.bits (n * w) x) =
      .ok ((List.range (n * w)).map fun i => some (x.getLsbD i)) := by
    show toBitList.scalarBitList (n * w) (.bits (n * w) x) = _
    simp [toBitList.scalarBitList]
    rfl
  show bitcast l (.int (n * w)) (.vec n (.int w)) (.bits (n * w) x) = _
  simp only [bitcast, hb, bind, Except.bind, List.length_map, List.length_range, Layout.scalarBits,
    ite_true, ofBitList]
  congr 2
  refine List.map_congr_left fun i hi => ?_
  rw [List.mem_range] at hi
  have hle : i * w + w ≤ n * w := by rw [← Nat.succ_mul]; exact Nat.mul_le_mul_right _ hi
  rw [← ofBitList.scalar_slice]
  congr 1
  refine List.ext_getElem (by simp; omega) fun j h1 h2 => ?_
  simp

/-- **`bitcast` of a word's slices back to a word gives the word**: for every layout `l`, memory
`m`, oracle numbers `ch`, lane count `n`, lane width `w` and `n * w`-bit word `x`, the `bitcast`
from `<n x iw>` to `i(n * w)` of the vector of `x`'s slices (`castV_split`'s value) is `x`; so
the round trip through the vector is the identity on every word. Every vector of `n` words of `w`
bits is the vector of slices of one word, so this is the `bitcast`'s value on every such
vector. -/
theorem castV_join (l : Layout) (m : Mem) (ch : Nat → Nat) {n w : Nat} (x : BitVec (n * w)) :
    castV l m .bitcast (.vec n (.int w))
      (.vec ((List.range n).map fun i => .bits w (x.extractLsb' (i * w) w))) (.int (n * w)) ch =
      .ok (.bits (n * w) x) := by
  have hf : ∀ k, ((List.range k).map fun i => (List.range w).map fun j =>
      some (x.getLsbD (i * w + j))).flatten =
      (List.range (k * w)).map fun i => some (x.getLsbD i) := by
    intro k
    induction k with
    | zero => simp
    | succ k ih =>
      rw [List.range_succ, List.map_append, List.flatten_append, ih, Nat.succ_mul, List.range_add,
        List.map_append]
      simp
  have hb : toBitList l (.vec n (.int w))
      (.vec ((List.range n).map fun i => .bits w (x.extractLsb' (i * w) w))) =
      .ok ((List.range (n * w)).map fun i => some (x.getLsbD i)) := by
    show (do
      let parts ← ((List.range n).map fun i => Val.bits w (x.extractLsb' (i * w) w)).mapM
        fun v => toBitList.scalarBitList w v
      return parts.flatten) = _
    rw [List.mapM_map]
    have hp : ∀ i, toBitList.scalarBitList w (.bits w (x.extractLsb' (i * w) w)) =
        pure ((List.range w).map fun j => some (x.getLsbD (i * w + j))) := fun i => by
      simp only [toBitList.scalarBitList, ite_true]
      congr 1
      refine List.map_congr_left fun j hj => ?_
      rw [List.mem_range] at hj
      simp [hj]
    simp only [Function.comp_def, hp, List.mapM_pure, pure_bind, hf]
    rfl
  have hs := ofBitList.scalar_slice (n * w) x 0
  simp only [Nat.zero_add, BitVec.extractLsb'_eq_self] at hs
  show bitcast l (.vec n (.int w)) (.int (n * w)) _ = _
  simp only [bitcast, hb, bind, Except.bind, List.length_map, List.length_range, Layout.scalarBits,
    ite_true]
  exact congrArg Except.ok hs

/-- **`bitcast <2 x i32>` to `i64` puts lane 0 low**: for every layout, memory, oracle numbers
and 32-bit words `a` and `b`, the `bitcast` of the vector `[a, b]` to `i64` is `b ++ a`, the word
with low half `a` and high half `b` (`castV_join` at `n = 2`, `w = 32`). -/
theorem castV_halves (l : Layout) (m : Mem) (ch : Nat → Nat) (a b : BitVec 32) :
    castV l m .bitcast (.vec 2 (.int 32)) (.vec [.bits 32 a, .bits 32 b]) (.int 64) ch =
      .ok (.bits 64 (b ++ a)) := by
  have e0 : (b ++ a).extractLsb' (0 * 32) 32 = a := BitVec.extractLsb'_append_eq_right
  have e1 : (b ++ a).extractLsb' (1 * 32) 32 = b := BitVec.extractLsb'_append_eq_left
  have := castV_join l m ch (n := 2) (w := 32) (b ++ a)
  rwa [show List.range 2 = [0, 1] from rfl, List.map_cons, List.map_cons, List.map_nil, e0,
    e1] at this

/-- `icmp p` on operands of type `t` (integers, or pointers compared by address). -/
def icmpV (l : Layout) (m : Mem) (p : ICmp) (t : Ty) : Val → Val → Except Fault Val :=
  lanes2 fun _ => strict2 fun x y => match x, y, t.elt with
    | .bits w a, .bits w' b, _ =>
      if h : w' = w then pure (.ofBool (p.holds a (b.cast h)))
      else throw (.unsupported "icmp operands of different widths")
    | .ptr u, .ptr v, .ptr a => do
      let w := (l.ptr a).1
      return .ofBool (p.holds (BitVec.ofNat w (← m.addr l a u)) (BitVec.ofNat w (← m.addr l a v)))
    | _, _, _ => throw (.unsupported "icmp of ill-typed operands")

/-- `fcmp p` with flags `fm` on operands of type `t`: FloatLib's IEEE comparison (`nnan` / `ninf`
with a NaN / infinite operand give poison; `FastMath.check` refuses the other flags but
`contract`). -/
def fcmpV (fm : FastMath) (p : FCmp) (t : Ty) (x y : Val) : Except Fault Val := do
  fm.check
  match t.elt with
  | .fp ft => lanes2 (fun _ => floats2 ft fun a b =>
    if fm.poisons [a, b] then .poison else .ofBool (p.holds (Model.compare a b))) x y
  | _ => throw (.unsupported "fcmp of non-float operands")

/-- `fneg` with flags `fm` of operands of type `t`: the sign flipped (FloatLib's `neg`), poison as
`withFlags` says. -/
def fnegV (fm : FastMath) (t : Ty) (x : Val) : Except Fault Val := do
  fm.check
  match t.elt with
  | .fp ft => lanes (fun _ x => match x with
    | .undef => throw (.unsupported "use of undef")
    | .poison => pure .poison
    | x => match x.float? ft with
      | some a => pure (match withFlags fm [a] (Model.neg a) with
        | some r => .ofFloat ft r
        | none => .poison)
      | none => throw (.unsupported "float operand of the wrong type")) x
  | _ => throw (.unsupported "fneg of a non-float operand")

/-- `select` of `a` and `b` (of type `t`) on condition `c`, lane by lane for a vector
condition; a poison condition gives poison. -/
def selectV (t : Ty) (c a b : Val) : Except Fault Val :=
  match c, a, b with
  | .vec cs, .vec xs, .vec ys =>
    if cs.length = xs.length ∧ xs.length = ys.length then
      .vec <$> (cs.zip (xs.zip ys)).mapM fun (c, a, b) => pick c a b t.elt
    else throw (.unsupported "select of vectors of different lengths")
  | c, a, b => pick c a b t
where
  /-- One lane of `select` at type `ty`: `a` if bit 0 of `c` is set, else `b`; poison for a poison
  condition; a fault for `undef` or a non-boolean. -/
  pick (c a b : Val) (ty : Ty) : Except Fault Val :=
    match c with
    | .bits _ x => pure (if x.getLsbD 0 then a else b)
    | .poison => pure (fill .poison ty)
    | .undef => throw (.unsupported "use of undef")
    | _ => throw (.unsupported "select on a non-boolean")

/-- `extractvalue` at indices `is`. -/
def extractV : Val → List Nat → Except Fault Val
  | v, [] => pure v
  | .agg xs, i :: is => match xs[i]? with
    | some x => extractV x is
    | none => throw (.unsupported "extractvalue index out of range")
  | _, _ :: _ => throw (.unsupported "extractvalue of a non-aggregate")

/-- `insertvalue` of `e` at indices `is`. -/
def insertV : Val → Val → List Nat → Except Fault Val
  | _, e, [] => pure e
  | .agg xs, e, i :: is => match xs[i]? with
    | some x => do return .agg (xs.set i (← insertV x e is))
    | none => throw (.unsupported "insertvalue index out of range")
  | _, _, _ :: _ => throw (.unsupported "insertvalue into a non-aggregate")

/-- `extractelement` of vector `v` (of type `t`) at `i`: poison if `i` is poison or out of
range. -/
def extractE (t : Ty) : Val → Val → Except Fault Val
  | .vec xs, .bits _ i => pure (xs[i.toNat]?.getD (fill .poison t.elt))
  | .vec _, .poison => pure (fill .poison t.elt)
  | _, _ => throw (.unsupported "extractelement of ill-typed operands")

/-- `insertelement` of `e` into vector `v` (of type `t`) at `i`: a poison vector if `i` is
poison or out of range. -/
def insertE (t : Ty) : Val → Val → Val → Except Fault Val
  | .vec xs, e, .bits _ i =>
    pure (if i.toNat < xs.length then .vec (xs.set i.toNat e) else fill .poison t)
  | .vec _, _, .poison => pure (fill .poison t)
  | _, _, _ => throw (.unsupported "insertelement of ill-typed operands")

/-- `shufflevector` of `a` and `b` (of type `t`) with mask `ms`: lane `j` is lane `ms[j]` of
`a` followed by `b`; a poison or `undef` mask element gives a poison lane (LangRef). -/
def shuffleV (t : Ty) : Val → Val → Val → Except Fault Val
  | .vec xs, .vec ys, .vec ms =>
    .vec <$> ms.mapM fun
      | .bits _ k => pure ((xs ++ ys)[k.toNat]?.getD (fill .poison t.elt))
      | .poison | .undef => pure (fill .poison t.elt)
      | _ => throw (.unsupported "shufflevector mask element")
  | _, _, _ => throw (.unsupported "shufflevector of ill-typed operands")

/-- What evaluating an operand reads: the layout, the memory (for addresses), the addresses of
the globals, the registers, and the step's oracle numbers. -/
structure Scope where
  /-- Builds a scope from its five fields. -/
  mk ::
  /-- The program's data layout. -/
  layout : Layout
  /-- The memory. -/
  mem : Mem
  /-- The pointer of each global, by name. -/
  globals : String → Option Ptr
  /-- The registers. -/
  regs : Nat → Option Val
  /-- The step's oracle numbers, read by float operations only (float casts included). -/
  ch : Nat → Nat

mutual
  /-- The value of operand `v` at type `t`. -/
  def evalV (s : Scope) (t : Ty) : Value → Except Fault Val
    | .loc n => match s.regs n with
      | some v => pure v
      | none => throw (.unsupported s!"local {n} has no value")
    | .glob n => match s.globals n with
      | some p => pure (.ptr p)
      | none => throw (.unsupported s!"global @{n} has no block")
    | .int i => match t with
      | .int w => pure (.bits w (BitVec.ofInt w i))
      | _ => throw (.unsupported "integer constant of a non-integer type")
    | .float lit => match t with
      | .fp ft => floatLit ft lit
      | _ => throw (.unsupported "float constant of a non-float type")
    | .null => pure (.ptr ⟨0, 0⟩)
    | .undef => pure (fill .undef t)
    | .poison => pure (fill .poison t)
    | .zero => match s.layout.zero t with
      | some v => pure v
      | none => throw (.unsupported "zeroinitializer of this type")
    | .vec es => .vec <$> evalTVs s es
    | .arr es | .struct es => .agg <$> evalTVs s es
    | .splat e => match t with
      | .vec n _ => do return .vec (List.replicate n (← evalTV s e))
      | _ => throw (.unsupported "splat of a non-vector type")
    | .gep fl src b idx => match b with
      | .mk (.ptr a) _ => do gep s.layout s.mem fl src a (← evalTVs s idx) (← evalTV s b)
      | _ => throw (.unsupported "GEP base of a non-pointer type")
    | .cast op v ty => match v with
      | .mk st _ =>
        if op.const then do castV s.layout s.mem op st (← evalTV s v) ty s.ch
        else throw (.unsupported "constant expression cast LangRef does not allow")

  /-- The value of a typed operand. -/
  def evalTV (s : Scope) : TValue → Except Fault Val
    | .mk t v => evalV s t v

  /-- The values of typed operands. -/
  def evalTVs (s : Scope) : List TValue → Except Fault (List Val)
    | [] => pure []
    | e :: es => do return (← evalTV s e) :: (← evalTVs s es)
end

end MojoProof.Sem
