import MojoProof.Sem.Float

/-!
# Data layout

Sizes, alignments and field offsets of types under a module's `target datalayout` string, read as
LangRef's "Data Layout" section specifies (`Layout.parse` refuses the specifications it does not
implement): pointer specifications `p[n]:size:abi[:pref[:idx]]` with index width `idx` the size,
integer `iN:abi`, float `fN:abi` and vector `vN:abi` alignments (in bits) and the alloca address
space `An`, over LangRef's defaults. A type absent from the integer specifications takes the
alignment of the next larger listed integer (the largest if none is larger); vectors and floats
absent from theirs take natural alignment, the store size rounded up to a power of two (LLVM's
`DataLayout::getAlignment`, read as TRUST T8 records). Struct fields sit at offsets rounded up to
their alignments; a struct's size is rounded up to its alignment, the largest of its fields'.

This module defines functions only; it proves nothing.
-/

namespace MojoProof.Sem

open LLVM

/-- The parts of a data layout the semantics reads, in bits: per address space the pointer size
(also its index width) and ABI alignment; the ABI alignments of integer, float and vector types
by size; the address space of `alloca`. -/
structure Layout where
  /-- Builds a layout from its five fields. -/
  mk ::
  /-- Per address space: the space, the pointer size (also its index width) and its ABI
  alignment. -/
  ptrs : List (Nat × Nat × Nat) := [(0, 64, 64)]
  /-- The ABI alignment of integer types, by width. -/
  ints : List (Nat × Nat) := [(1, 8), (8, 8), (16, 16), (32, 32), (64, 32)]
  /-- The ABI alignment of float types, by width. -/
  floats : List (Nat × Nat) := [(16, 16), (32, 32), (64, 64), (128, 128)]
  /-- The ABI alignment of vector types, by size. -/
  vecs : List (Nat × Nat) := [(64, 64), (128, 128)]
  /-- The address space of `alloca`. -/
  allocaSpace : Nat := 0
  deriving Repr, Inhabited, BEq

namespace Layout

/-- `xs` with the entry for key `k` replaced by `(k, v)`. -/
def set {β : Type} (xs : List (Nat × β)) (k : Nat) (v : β) : List (Nat × β) :=
  (k, v) :: xs.filter (·.1 != k)

/-- The layout a `target datalayout` string describes (LangRef's defaults for the rest), or the
first specification the semantics does not implement. Read: `e`, `p`, `i`, `f`, `v`, `A`.
Skipped, as they do not change the meaning of a program: `S`, `n`, `m`, and `P0`, `G0`, `a:0`.
Refused: big-endian `E`; a pointer whose index width is not its size (LangRef, "getelementptr":
offsets would wrap in the low index-width bits only); an aggregate ABI alignment other than 0;
program or global address spaces other than 0; function pointer alignment `F`; non-integral
spaces `ni`; anything else. -/
def parse (s : String) : Except String Layout := do
  let mut l : Layout := {}
  for spec in s.splitOn "-" do
    let bad := s!"unsupported datalayout specification '{spec}'"
    let raw := (String.ofList (spec.toList.drop 1)).splitOn ":"
    if spec.isEmpty || spec == "e" then continue
    match spec.toList.headD ' ', raw.mapM String.toNat?, raw with
    | 'p', _, a :: rest =>
      let space := if a.isEmpty then some 0 else a.toNat?
      match space, rest.mapM String.toNat? with
      | some a, some (sz :: abi :: more) =>
        unless more.length ≤ 1 || more == [more.headD 0, sz] do throw bad
        l := { l with ptrs := set l.ptrs a (sz, abi) }
      | _, _ => throw bad
    | 'i', some [w, abi], _ | 'i', some [w, abi, _], _ => l := { l with ints := set l.ints w abi }
    | 'f', some [w, abi], _ | 'f', some [w, abi, _], _ =>
      l := { l with floats := set l.floats w abi }
    | 'v', some [w, abi], _ | 'v', some [w, abi, _], _ => l := { l with vecs := set l.vecs w abi }
    | 'A', some [a], _ => l := { l with allocaSpace := a }
    | 'S', some [_], _ | 'n', some _, _ | 'P', some [0], _ | 'G', some [0], _ => pure ()
    | 'm', _, ["", _] => pure ()
    | 'a', _, ["", "0"] | 'a', _, ["", "0", _] => pure ()
    | _, _, _ => throw bad
  return l

/-- Pointer size and ABI alignment of address space `a` (unlisted spaces use space 0's). -/
def ptr (l : Layout) (a : Nat) : Nat × Nat :=
  match l.ptrs.find? (·.1 == a), l.ptrs.find? (·.1 == 0) with
  | some (_, s), _ => s
  | none, some (_, s) => s
  | none, none => (64, 64)

/-- `n` rounded up to a multiple of `a` (unchanged for `a = 0`). -/
def roundUp (n a : Nat) : Nat := if a = 0 then n else (n + a - 1) / a * a

/-- The ABI alignment in bits of `iw`: its entry, else the next larger listed width's, else the
largest listed width's. -/
def intAlign (l : Layout) (w : Nat) : Nat :=
  let larger := l.ints.filter (·.1 ≥ w)
  let pick := fun (xs : List (Nat × Nat)) (better : Nat → Nat → Bool) =>
    xs.foldl (fun acc x => match acc with
      | none => some x
      | some y => if better x.1 y.1 then some x else some y) none
  match pick larger (· < ·), pick l.ints (· > ·) with
  | some (_, a), _ => a
  | none, some (_, a) => a
  | none, none => w

/-- The size in bits of a scalar type (integers, floats, pointers); `0` for other types. -/
def scalarBits (l : Layout) : Ty → Nat
  | .int w => w
  | .fp t => t.fmt.bitWidth
  | .ptr a => (l.ptr a).1
  | _ => 0

mutual
  /-- The ABI alignment of a type, in bytes (at least 1). -/
  def align (l : Layout) : Ty → Nat
    | .int w => max 1 (l.intAlign w / 8)
    | .fp t =>
      match l.floats.find? (·.1 == t.fmt.bitWidth) with
      | some (_, a) => max 1 (a / 8)
      | none => (t.fmt.bitWidth / 8).nextPowerOfTwo
    | .ptr a => max 1 ((l.ptr a).2 / 8)
    | .vec n t =>
      match l.vecs.find? (·.1 == n * l.scalarBits t) with
      | some (_, a) => max 1 (a / 8)
      | none => ((n * l.scalarBits t + 7) / 8).nextPowerOfTwo
    | .arr _ t => l.align t
    | .struct fs => l.alignAll fs
    | _ => 1

  /-- The largest alignment of a list of types (1 for none). -/
  def alignAll (l : Layout) : List Ty → Nat
    | [] => 1
    | t :: ts => max (l.align t) (l.alignAll ts)
end

/-- The store size of a scalar or vector type in bytes: its bits rounded up to bytes. -/
def storeSize (l : Layout) : Ty → Nat
  | .vec n t => (n * l.scalarBits t + 7) / 8
  | t => (l.scalarBits t + 7) / 8

mutual
  /-- The allocation size of a type in bytes: the distance between consecutive array elements. -/
  def size (l : Layout) : Ty → Nat
    | .arr n t => n * l.size t
    | .struct fs => roundUp (l.fieldsEnd 0 fs) (l.alignAll fs)
    | .void | .label | .metadata => 0
    | t => roundUp (l.storeSize t) (l.align t)

  /-- The end offset of fields `fs` laid out from offset `off`. -/
  def fieldsEnd (l : Layout) (off : Nat) : List Ty → Nat
    | [] => off
    | t :: ts => l.fieldsEnd (roundUp off (l.align t) + l.size t) ts
end

/-- The offset of field `i` of fields `fs` laid out from offset `off`. -/
def fieldOffset (l : Layout) (off : Nat) : List Ty → Nat → Nat
  | [], _ => off
  | t :: _, 0 => roundUp off (l.align t)
  | t :: ts, i + 1 => l.fieldOffset (roundUp off (l.align t) + l.size t) ts i

end Layout

end MojoProof.Sem
