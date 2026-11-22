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
  signed (sums: unsigned address) range; under `nuw` if an index is negative, a truncation
  changes an index's unsigned value, or a term, a partial sum or the address plus a partial sum
  reaches `2 ^ width`; under `inbounds` with a nonzero index, if the
  base offset or the offset after a partial sum lies outside `[0, size]` of the base's block
  (LangRef, "getelementptr"). The `nuw` rule makes more results poison than LangRef's (a
  negative index is poison here); more poison only removes behaviors a proof may rely on.
* A cast in a constant expression is one LangRef admits there (`CastOp.const`; LangRef, "Constant
  Expressions"); the others are unsupported. So evaluating an operand reads no oracle number.
* Pointer comparisons and `ptrtoint` read addresses (`Mem.addr`); `addrspacecast` keeps the block
  and offset, except that a cast of a null-based pointer is unsupported (LangRef does not fix its
  address). `fptoui`, `fptosi` and `inttoptr` are unsupported.
* A float literal is parsed as LLVM's assembler does: a decimal or `0x` literal is a `double`,
  rounded to nearest even, and must convert exactly to the operand's type; `0xH` and `0xR` are
  the bits of a `half` and a `bfloat`.

This module defines functions only; it proves nothing.
-/

namespace MojoProof.Sem

open FloatLib.Floats.Formats.BinaryInterchange LLVM

/-- The element type of a vector type; any other type itself. -/
def _root_.MojoProof.LLVM.Ty.elt : Ty → Ty
  | .vec _ t => t
  | t => t

/-- The value of type `t` all of whose scalars are `x` (`poison` or `undef`). -/
def fill (x : Val) : Ty → Val
  | .vec n _ => .vec (List.replicate n x)
  | .arr n t => .agg (List.replicate n (fill x t))
  | .struct fs => .agg (fs.map fun t => fill x t)
  | _ => x

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

/-- The value of float literal `lit` at float type `t`. -/
def floatLit (t : FloatTy) (lit : FloatLit) : Except Fault Val :=
  match lit with
  | .hex "H" b => if t = .half then pure (.bits 16 (BitVec.ofNat 16 b)) else wrong
  | .hex "R" b => if t = .bfloat then pure (.bits 16 (BitVec.ofNat 16 b)) else wrong
  | .hex "" b => exactIn (Model.ofNatBits b)
  | .dec neg i f e =>
    match (i ++ f).toNat? with
    | some d =>
      let x := Model.ofRat .binary64 ((d : Rat) * (10 : Rat) ^ (e - f.length))
      exactIn (if neg then Model.neg x else x)
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

/-- The steps of the indices `is` of a GEP with source type `src`: each index with the byte
offset it adds. The first index steps over `src`, each later one into the current type (array and
vector elements by allocation size, struct fields by field offset). -/
def gepSteps (l : Layout) (src : Ty) : List Int → Except Fault (List (Int × Int))
  | [] => pure []
  | i :: is => do return (i, i * l.size src) :: (← into src is)
where
  /-- The steps of the later indices into type `t`: array and vector elements by allocation size,
  struct fields by field offset; a fault for a struct index out of range or an index into a
  scalar type. -/
  into : Ty → List Int → Except Fault (List (Int × Int))
    | _, [] => pure []
    | .arr _ e, i :: is | .vec _ e, i :: is => do return (i, i * l.size e) :: (← into e is)
    | .struct fs, i :: is =>
      if h : 0 ≤ i ∧ i.toNat < fs.length then do
        return (i, l.fieldOffset 0 fs i.toNat) :: (← into (fs[i.toNat]'h.2) is)
      else throw (.unsupported "struct index out of range")
    | _, _ :: _ => throw (.unsupported "index into a scalar type")

/-- `getelementptr` with flags `fl` and source type `src` on pointer `p` of address space `a`, with
index values `idx` (scalars only). -/
def gepPtr (l : Layout) (m : Mem) (fl : GepFlags) (src : Ty) (a : Nat) (p : Ptr)
    (idx : List Val) : Except Fault Val := do
  let iw := (l.ptr a).1
  -- each index: its value at the index width, lossless in the signed and in the unsigned sense
  let some ix := idx.mapM (fun
      | .bits w b =>
        let i := if w ≤ iw then b.toInt else Int.bmod b.toInt (2 ^ iw)
        some (some (i, i == b.toInt, i ≥ 0 && b.toNat < 2 ^ iw))
      | .poison => some none
      | _ => none)
    | throw (.unsupported "GEP index that is not an integer scalar")
  let some ix := ix.mapM id | return .poison
  let steps ← gepSteps l src (ix.map (·.1))
  let terms := steps.map (·.2)
  let sums := (terms.scanl (· + ·) 0).tail
  let ad : Int := (← m.addr l a p)
  let badS := ix.any (!·.2.1) || (terms ++ sums).any (outS iw) ||
    sums.any fun s => ad + s < 0 || ad + s ≥ 2 ^ iw
  let badU := ix.any (!·.2.2) || (terms ++ sums).any (· ≥ 2 ^ iw) ||
    sums.any fun s => ad + s ≥ 2 ^ iw
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
