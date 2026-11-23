import MojoProof.Sem.Value

/-!
# Operations on values

The value-level operations that need no memory: integer arithmetic with its poison flags,
integer comparison, float arithmetic with LLVM's freedoms (`MojoProof.Sem.Float`), and the casts
other than `ptrtoint`. Scalars only; the thread semantics applies them lane by lane to vectors.

Integer operations follow LangRef's instruction sections: `nuw` / `nsw` overflow, `exact` with
a nonzero remainder or shifted-out bits, `disjoint` with common bits, and shift amounts of at
least the width give poison; division or remainder by zero, and signed division or remainder of
the least value by -1, are undefined behavior, as is a poison divisor. Any other poison operand
gives poison.

Proved here, for every float type, format and all operands: a float scalar reads back as the value
it was made from (`Val.float?_ofFloat`), and only that scalar reads as that value
(`Val.float?_eq_some`); a finite result of an operation, whatever its flags and oracle, has the
real value of its IEEE 754 result, which is finite (`toReal_withFlags`); so an `fmul` result is a
rounded product of its operands (`isProd_withFlags`), as `contract_error` assumes; and a finite
value of a contracted `fadd` / `fsub` has the real value of its finite `contract` result
(`floatBin_contract`), so `contract_error` bounds it. For every width and word, the scalar
`ofBitList` reads from a run of a word's bits is that slice of the word
(`ofBitList.scalar_slice`).
-/

namespace MojoProof.Sem

open FloatLib.Floats.Formats.BinaryInterchange LLVM

/-- The integer value `i` is outside the signed range of `w` bits. -/
def outS (w : Nat) (i : Int) : Bool := !(decide (-(2 ^ (w - 1) : Int) ≤ i ∧ i < 2 ^ (w - 1)))

/-- An integer binary operator on words. -/
def intBits {w : Nat} (op : BinOp) (fl : IntFlags) (a b : BitVec w) : Except Fault Val :=
  let res (r : BitVec w) (bad : Bool) : Except Fault Val :=
    pure (if bad then .poison else .bits w r)
  let k := b.toNat
  match op with
  | .add =>
    res (a + b) (fl.nuw && a.toNat + b.toNat ≥ 2 ^ w || fl.nsw && outS w (a.toInt + b.toInt))
  | .sub => res (a - b) (fl.nuw && a.toNat < b.toNat || fl.nsw && outS w (a.toInt - b.toInt))
  | .mul =>
    res (a * b) (fl.nuw && a.toNat * b.toNat ≥ 2 ^ w || fl.nsw && outS w (a.toInt * b.toInt))
  | .udiv => if b = 0 then throw (.ub "udiv by zero") else res (a / b) (fl.exact && a % b != 0)
  | .urem => if b = 0 then throw (.ub "urem by zero") else res (a % b) false
  | .sdiv =>
    if b = 0 then throw (.ub "sdiv by zero")
    else if a = BitVec.intMin w ∧ b = BitVec.allOnes w then throw (.ub "sdiv overflow")
    else res (a.sdiv b) (fl.exact && a.srem b != 0)
  | .srem =>
    if b = 0 then throw (.ub "srem by zero")
    else if a = BitVec.intMin w ∧ b = BitVec.allOnes w then throw (.ub "srem overflow")
    else res (a.srem b) false
  | .shl =>
    res (a <<< k)
      (k ≥ w || fl.nuw && (a <<< k) >>> k != a || fl.nsw && (a <<< k).sshiftRight k != a)
  | .lshr => res (a >>> k) (k ≥ w || fl.exact && (a >>> k) <<< k != a)
  | .ashr => res (a.sshiftRight k) (k ≥ w || fl.exact && (a.sshiftRight k) <<< k != a)
  | .and => res (a &&& b) false
  | .or => res (a ||| b) (fl.disjoint && a &&& b != 0)
  | .xor => res (a ^^^ b) false

/-- Whether an operator divides (its divisor must not be poison). -/
def _root_.MojoProof.LLVM.BinOp.divides : BinOp → Bool
  | .udiv | .sdiv | .urem | .srem => true
  | _ => false

/-- An integer binary operator on scalar values of width `w`. -/
def intBin (w : Nat) (op : BinOp) (fl : IntFlags) : Val → Val → Except Fault Val
  | .bits w₁ a, .bits w₂ b =>
    if h : w₁ = w ∧ w₂ = w then intBits op fl (a.cast h.1) (b.cast h.2)
    else throw (.unsupported "integer operands of the wrong width")
  | .undef, _ | _, .undef => throw (.unsupported "use of undef")
  | _, .poison => if op.divides then throw (.ub "poison divisor") else pure .poison
  | .poison, .bits _ b => if op.divides ∧ b.toNat = 0 then throw (.ub "division by zero")
    else pure .poison
  | _, _ => throw (.unsupported "integer operator on non-integers")

/-- The predicate of `icmp p` on words. -/
def _root_.MojoProof.LLVM.ICmp.holds {w : Nat} (p : ICmp) (a b : BitVec w) : Bool :=
  match p with
  | .eq => a == b
  | .ne => a != b
  | .ugt => b.ult a
  | .uge => b.ule a
  | .ult => a.ult b
  | .ule => a.ule b
  | .sgt => b.slt a
  | .sge => b.sle a
  | .slt => a.slt b
  | .sle => a.sle b

/-- An `i1` value. -/
def Val.ofBool (b : Bool) : Val := .bits 1 (if b then 1 else 0)

/-- The FloatLib value of a scalar of float type `t`. -/
def Val.float? (t : FloatTy) : Val → Option (Model t.fmt)
  | .bits w b => if h : w = t.fmt.bitWidth then some (Model.ofBits (b.cast h)) else none
  | _ => none

/-- The scalar of float type `t` with FloatLib value `x`. -/
def Val.ofFloat (t : FloatTy) (x : Model t.fmt) : Val := .bits t.fmt.bitWidth x.toBits

/-- The scalar of a FloatLib value reads back as that value. -/
@[simp] theorem Val.float?_ofFloat (t : FloatTy) (x : Model t.fmt) :
    (Val.ofFloat t x).float? t = some x := by
  simp [Val.float?, Val.ofFloat]

/-- A scalar reads as the float value `a` of type `t` exactly when it is the scalar made from
`a`. -/
theorem Val.float?_eq_some {t : FloatTy} {x : Val} {a : Model t.fmt} :
    x.float? t = some a ↔ x = .ofFloat t a := by
  refine ⟨fun h => ?_, by rintro rfl; simp⟩
  cases x <;> simp [Val.float?] at h
  obtain ⟨rfl, rfl⟩ := h
  simp [Val.ofFloat]

/-- The fast-math flags the semantics implements are `nnan`, `ninf` and `contract`; an operation
with `nsz`, `reassoc`, `arcp` or `afn` is unsupported (none occurs in the corpus). -/
def _root_.MojoProof.LLVM.FastMath.check (fm : FastMath) : Except Fault Unit :=
  if fm.nsz || fm.reassoc || fm.arcp || fm.afn then
    throw (.unsupported "fast-math flags nsz/reassoc/arcp/afn")
  else pure ()

/-- Flags `fm` make an operation on or giving the values `xs` poison: `nnan` with a NaN, `ninf`
with an infinity (LangRef, "Fast-Math Flags"). -/
def _root_.MojoProof.LLVM.FastMath.poisons {fmt : FloatFormat} (fm : FastMath)
    (xs : List (Model fmt)) : Bool :=
  fm.nnan && xs.any (·.isNaN) || fm.ninf && xs.any (·.isInfinite)

/-- A float scalar operation with fast-math flags `fm`, operands `args` and IEEE 754 result `r`:
`none` if the flags make it poison (`FastMath.poisons`). -/
def withFlags {fmt : FloatFormat} (fm : FastMath) (args : List (Model fmt)) (r : Model fmt) :
    Option (Model fmt) :=
  if fm.poisons (r :: args) then none else some r

/-- A finite value an operation gives with flags `fm` and oracle number `n` (as `floatBin`
computes it) from the IEEE 754 result `r` has `r`'s real value, and `r` is finite: the oracle only
replaces a NaN. -/
theorem toReal_withFlags {fmt : FloatFormat} {fm : FastMath} {args : List (Model fmt)}
    {r x : Model fmt} {n : Nat} (h : withFlags fm args (deliver r n) = some x)
    (hx : x.isFinite = true) : r.isFinite = true ∧ x.toReal = r.toReal := by
  unfold withFlags at h
  split_ifs at h
  cases h
  cases hm : r.isNaN
  · rw [deliver_of_isNaN_eq_false hm] at hx ⊢
    exact ⟨hx, rfl⟩
  · simp [Model.isFinite_eq_false_of_isNaN (isNaN_deliver hm n)] at hx

/-- A value `fmul` gives with flags `fm` and oracle number `n` (as `floatBin` computes it) is a
rounded product of its operands, the hypothesis of `contract_error`. -/
theorem isProd_withFlags {fmt : FloatFormat} {fm : FastMath} {a b x : Model fmt} {n : Nat}
    (h : withFlags fm [a, b] (deliver (Model.mul a b) n) = some x) : IsProd x (some (a, b)) := by
  rintro _ _ ⟨⟩ hx
  exact toReal_withFlags h hx

/-- A float binary operator `op` with flags `fm` on scalars of type `t`, where `px` / `py` are the
`fmul contract` factors of the operands; `n` is the oracle number for the choices (contraction
`n % 3`, NaN `n / 3`). -/
def floatBin (t : FloatTy) (op : FBinOp) (fm : FastMath) (x y : Val)
    (px py : Option (Val × Val)) (n : Nat) : Except Fault Val := do
  fm.check
  match x, y with
  | .undef, _ | _, .undef => throw (.unsupported "use of undef")
  | .poison, _ | _, .poison => return .poison
  | _, _ => pure ()
  let some a := x.float? t | throw (.unsupported "float operand of the wrong type")
  let some b := y.float? t | throw (.unsupported "float operand of the wrong type")
  let some f := fbin (fmt := t.fmt) op | throw (.unsupported "frem")
  let prod (p : Option (Val × Val)) : Option (Model t.fmt × Model t.fmt) := do
    let (u, v) ← p
    return (← u.float? t, ← v.float? t)
  let r := match op with
    | .fadd | .fsub =>
      if fm.contract then contract (op == .fsub) a b (prod px) (prod py) n else f a b
    | _ => f a b
  return match withFlags fm [a, b] (deliver r (n / 3)) with
    | some r => .ofFloat t r
    | none => .poison

/-- A finite value `floatBin` stores for an `fadd` / `fsub` with `contract`, on float scalars `a`,
`b` with factors `pa`, `pb`, whatever the other flags (`nnan`, `ninf`; the others make it
unsupported) and the oracle number `n`, has the real value of the finite `contract` result that
`contract_error` bounds. -/
theorem floatBin_contract {t : FloatTy} {op : FBinOp} (hop : op = .fadd ∨ op = .fsub)
    {fm : FastMath} (hc : fm.contract = true) {a b r : Model t.fmt}
    {pa pb : Option (Model t.fmt × Model t.fmt)} {n : Nat}
    (h : floatBin t op fm (.ofFloat t a) (.ofFloat t b)
      (pa.map fun (u, v) => (.ofFloat t u, .ofFloat t v))
      (pb.map fun (u, v) => (.ofFloat t u, .ofFloat t v)) n = .ok (.ofFloat t r))
    (hr : r.isFinite = true) :
    (contract (op == .fsub) a b pa pb n).isFinite = true ∧
      r.toReal = (contract (op == .fsub) a b pa pb n).toReal := by
  by_cases hf : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = true
  · simp [floatBin, FastMath.check, hf, bind, Except.bind, throw, throwThe,
      MonadExceptOf.throw] at h
  rcases hop with rfl | rfl <;> rcases pa with _ | ⟨u, v⟩ <;> rcases pb with _ | ⟨u', v'⟩ <;>
  · simp only [Bool.not_eq_true] at hf
    simp [floatBin, FastMath.check, hf, hc, Val.ofFloat, Val.float?, fbin,
      Model.ofBits_toBits] at h
    split at h
    · simp [pure, Except.pure] at h
      have := congrArg Model.ofBits h
      simp only [Model.ofBits_toBits] at this
      subst this
      exact toReal_withFlags (by assumption) hr
    · simp [pure, Except.pure] at h

/-- `fptrunc` / `fpext` of a scalar from float type `s` to `t` (FloatLib's correctly rounded
conversion; a NaN result is any NaN, by oracle number `n`). -/
def floatCast (s t : FloatTy) (x : Val) (n : Nat) : Except Fault Val :=
  match x with
  | .undef => throw (.unsupported "use of undef")
  | .poison => pure .poison
  | _ => match x.float? s with
    | some a => pure (.ofFloat t (deliver (Model.cast s.fmt t.fmt a) n))
    | none => throw (.unsupported "float operand of the wrong type")

/-- `sitofp` (`signed`) / `uitofp` of a scalar to float type `t`: the integer rounded once to
nearest even. -/
def intToFloat (signed : Bool) (t : FloatTy) : Val → Except Fault Val
  | .bits _ b =>
    pure (.ofFloat t (Model.ofRat t.fmt (if signed then (b.toInt : Rat) else (b.toNat : Rat))))
  | .poison => pure .poison
  | .undef => throw (.unsupported "use of undef")
  | _ => throw (.unsupported "sitofp/uitofp of a non-integer")

/-- `trunc`, `zext`, `sext` of a scalar to `w` bits. -/
def intCast (op : CastOp) (w : Nat) : Val → Except Fault Val
  | .bits _ b => match op with
    | .trunc | .zext => pure (.bits w (b.setWidth w))
    | .sext => pure (.bits w (b.signExtend w))
    | _ => throw (.unsupported "integer cast")
  | .poison => pure .poison
  | .undef => throw (.unsupported "use of undef")
  | _ => throw (.unsupported "integer cast of a non-integer")

/-- The bits of a value of type `t` from least to most significant (lane 0 first), `none` for a
poison bit; pointers have no bits here. -/
def toBitList (l : Layout) : Ty → Val → Except Fault (List (Option Bool))
  | .vec _ t, .vec xs => do
    let parts ← xs.mapM fun x => scalarBitList (l.scalarBits t) x
    return parts.flatten
  | t, x => scalarBitList (l.scalarBits t) x
where
  /-- The `w` bits of a scalar of width `w`, least significant first: all `none` for poison; a
  fault for `undef`, a pointer or another width. -/
  scalarBitList (w : Nat) : Val → Except Fault (List (Option Bool))
    | .bits w' b => if w' = w then pure ((List.range w).map fun i => some (b.getLsbD i))
      else throw (.unsupported "bitcast of a value of the wrong width")
    | .poison => pure (List.replicate w none)
    | .undef => throw (.unsupported "use of undef")
    | _ => throw (.unsupported "bitcast of a pointer")

/-- The value of type `t` with bits `bs` (least significant first); a scalar with a poison bit is
poison. -/
def ofBitList (l : Layout) (t : Ty) (bs : List (Option Bool)) : Val :=
  match t with
  | .vec n e =>
    let w := l.scalarBits e
    .vec ((List.range n).map fun i => scalar w ((bs.drop (i * w)).take w))
  | t => scalar (l.scalarBits t) bs
where
  /-- The scalar of width `w` with bits `bs`, least significant first; poison if a bit is
  `none`. -/
  scalar (w : Nat) (bs : List (Option Bool)) : Val :=
    match bs.mapM id with
    | some bits =>
      .bits w (BitVec.ofNat w ((bits.zipIdx.map fun (b, i) => if b then 2 ^ i else 0).sum))
    | none => .poison

/-- `bitcast` between non-pointer types of the same size: the same bits read at type `t`. -/
def bitcast (l : Layout) (s t : Ty) (x : Val) : Except Fault Val := do
  match s, t with
  | .ptr _, .ptr _ => return x
  | _, _ =>
    let bs ← toBitList l s x
    let width := match t with
      | .vec n e => n * l.scalarBits e
      | t => l.scalarBits t
    if bs.length = width then return ofBitList l t bs
    else throw (.unsupported "bitcast between types of different sizes")

/-- **A scalar read from bits of a word is the word's slice**: for every width `w`, word `x` of
every width `v` and offset `o`, the scalar of width `w` whose bits, least significant first, are
`x`'s bits `o` to `o + w - 1` (none poison) is `x.extractLsb' o w`; at `o = 0` and `v = w`, it is
`x` itself. For every word. -/
theorem ofBitList.scalar_slice (w : Nat) {v : Nat} (x : BitVec v) (o : Nat) :
    ofBitList.scalar w ((List.range w).map fun j => some (x.getLsbD (o + j))) =
      .bits w (x.extractLsb' o w) := by
  have hsum : ∀ n k : Nat, (((List.range k).map n.testBit).zipIdx.map
      fun (b, i) => if b then 2 ^ i else 0).sum = n % 2 ^ k := by
    intro n k
    induction k with
    | zero => simp [Nat.mod_one]
    | succ k ih =>
      rw [List.range_succ, List.map_append, List.zipIdx_append, List.map_append, List.sum_append,
        ih, Nat.mod_pow_succ]
      rcases Nat.mod_two_eq_zero_or_one (n / 2 ^ k) with h | h <;>
        simp [Nat.testBit_eq_decide_div_mod_eq, h]
  have hm : ∀ bs : List Bool, (bs.map some).mapM id = some bs := fun bs => by
    induction bs with
    | nil => rfl
    | cons b bs ih => simp only [List.map_cons, List.mapM_cons, ih]; rfl
  have he : (List.range w).map (fun j => some (x.getLsbD (o + j))) =
      ((List.range w).map (x.toNat >>> o).testBit).map some := by
    simp only [List.map_map]
    refine List.map_congr_left fun j _ => ?_
    simp only [Function.comp, Nat.testBit_shiftRight]
    rfl
  simp only [ofBitList.scalar, he, hm, hsum]
  congr 1
  apply BitVec.eq_of_toNat_eq
  simp

end MojoProof.Sem
