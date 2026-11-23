import MojoProof.Sem.Layout

/-!
# Values and memory

Run-time values, memory bytes, and the memory: blocks with byte contents, the encoding of values
as bytes, and loads, stores and allocation.

* A scalar of type `iN`, `half`, `bfloat`, `float` or `double` is a word of its width
  (`Val.bits`); a pointer is a block and an offset (`Ptr`); vectors and aggregates hold their
  elements. A scalar may be `poison`, or `undef` (the constant): a run may move `undef` around
  but any operation on it stops the run as unsupported, so a run that ends normally never
  depends on an `undef` value.
* Memory is a map from block numbers to blocks. Block 0 is the null block: size 0, never live.
  A block has an address space, a size, a liveness flag, an owner, bytes, and two addresses (in
  its own address space and in the generic space) that a skeleton choice gives at allocation as
  multiples of the block's alignment (`Grid.start`, `Ctx.addr`); `ptrtoint` and pointer
  comparisons read them. An allocated block's initial bytes are kept as a tree (`ByteTree`):
  a read of one of `n` bytes walks one path of about `log₂ n` nodes, where `List.getD` walks the
  list up to the byte. Compiled code reads the list (`ByteTree.bytesOf_csimp`).
* A byte holds data, byte `i` of a pointer, `undef` or `poison` (LangRef, "Memory Model").
  Values are stored little-endian at their store size (LangRef, "Data Layout"); aggregates
  with their padding (undefined bytes). A load of a scalar with a poison byte is poison, with an
  undefined byte (and no poison one) `undef`, with a nonzero bit beyond its width poison.
* An access is undefined behavior unless its block is live, its owner admits the accessing
  thread, it lies within the block, and its address is a multiple of the access alignment; a
  store to a read-only block is undefined behavior. The owner of a thread's local memory (its
  `alloca`s and `byval` copies) is the thread, of shared memory the block of threads: PTX ISA
  9.5 makes local memory private to each thread (section 5.1.5) and shared memory accessible to
  the threads of its cluster (5.1.7; a launch here has no clusters, so a cluster is one block of
  threads). LLVM's single memory does not say what another thread's access means.
* The memory records a trace, newest first, of the accesses of the run (thread, block, offset,
  bytes, write or read, by `atomicrmw` or not, by a load with `!invariant.load` or not) and of
  the barriers that completed: ghost state
  that the semantics only extends (`Mem.log`) and never reads, so that race freedom can be
  stated (MojoProof/Sem/Spec.lean). A store records the bytes it writes (`Mem.store`).

This module defines data and functions. Its only theorems are about `ByteTree`: the tree of a
list reads the list (`ByteTree.get_ofList`, from `ByteTree.halves_getD` and
`ByteTree.halves_length`), so `ByteTree.bytesOf init` is `fun i => init.getD i .undef`
(`ByteTree.bytesOf_eq`), and compiled code runs the latter (`ByteTree.bytesOf_csimp`).
-/

namespace MojoProof.Sem

open LLVM

/-- A pointer: a memory block and a byte offset into it (block 0 is null). -/
structure Ptr where
  /-- Builds a pointer from a block number and an offset. -/
  mk ::
  /-- The block's number (0 is null). -/
  block : Nat
  /-- The byte offset into the block, possibly negative or past its end. -/
  off : Int
  deriving DecidableEq, Repr, Inhabited

/-- Run-time values. -/
inductive Val
  /-- A word of `w` bits: an integer, or the bits of a float. -/
  | bits (w : Nat) (b : BitVec w)
  /-- A pointer. -/
  | ptr (p : Ptr)
  /-- LLVM's `poison`. -/
  | poison
  /-- LLVM's `undef`. -/
  | undef
  /-- A vector, by lane. -/
  | vec (xs : List Val)
  /-- An aggregate (a struct or an array), by element. -/
  | agg (xs : List Val)
  deriving Repr, Inhabited

/-- Contents of one memory byte. -/
inductive MemByte
  /-- A byte of data. -/
  | byte (b : BitVec 8)
  /-- Byte `i` of a stored pointer `p`. -/
  | ptr (p : Ptr) (i : Nat)
  /-- An undefined byte. -/
  | undef
  /-- A poison byte. -/
  | poison
  deriving DecidableEq, Repr, Inhabited

/-- Why a run stops abnormally: undefined behavior, or a construct the semantics gives no meaning
to (including any use of `undef`). Theorems about kernels show that no run stops either way. -/
inductive Fault
  /-- Undefined behavior, with a message saying which. -/
  | ub (msg : String)
  /-- A construct the semantics gives no meaning to, with a message saying which. -/
  | unsupported (msg : String)
  deriving Repr, Inhabited

/-- Who may access a block: every thread, the threads of one block of threads (by number), or
one thread (by number in the grid). -/
inductive Owner
  /-- Every thread. -/
  | all
  /-- The threads of block of threads `b`. -/
  | cta (b : Nat)
  /-- The thread numbered `n` in the grid. -/
  | thread (n : Nat)
  deriving DecidableEq, Repr, Inhabited

/-- A thread that accesses memory: its number in the grid and the number of its block. -/
structure Who where
  /-- Builds a `Who` from a thread number and a block number. -/
  mk ::
  /-- The thread's number in the grid. -/
  thread : Nat
  /-- The number of the thread's block of threads. -/
  cta : Nat
  deriving DecidableEq, Repr, Inhabited

/-- Owner `o` admits thread `w`. -/
def Owner.admits : Owner → Who → Bool
  | .all, _ => true
  | .cta b, w => w.cta == b
  | .thread n, w => w.thread == n

/-- A memory block. -/
structure Block where
  /-- Builds a block from its eight fields. -/
  mk ::
  /-- The address space. -/
  space : Nat
  /-- The size in bytes. -/
  size : Nat
  /-- Whether the block is live; an access to a dead block is undefined behavior. -/
  live : Bool
  /-- Whether the block is read-only; a store to it is undefined behavior. -/
  readOnly : Bool
  /-- Who may access the block. -/
  owner : Owner
  /-- The bytes, by offset. -/
  bytes : Nat → MemByte
  /-- The block's address in its own address space. -/
  addr : Nat
  /-- The block's address in the generic address space. -/
  gaddr : Nat

/-- An access by thread `who` of `len` bytes from pointer `ptr`: a write or a read, by an
`atomicrmw` of operation `op` (`atomic = some op`) or not, by a load with `!invariant.load` or
not. -/
structure Access where
  /-- Builds an access from its six fields. -/
  mk ::
  /-- The accessing thread. -/
  who : Who
  /-- The pointer the access starts at. -/
  ptr : Ptr
  /-- The number of bytes. -/
  len : Nat
  /-- Whether the access writes. -/
  write : Bool
  /-- The operation, for an access by an `atomicrmw`. -/
  atomic : Option RmwOp
  /-- Whether the access is a load with `!invariant.load`. -/
  invariant : Bool
  deriving DecidableEq, Repr

/-- An event of a run's trace: an access, or the completion of a barrier by the threads of block
of threads `cta`. -/
inductive Event
  /-- A memory access. -/
  | access (a : Access)
  /-- A barrier completed by the threads of block of threads `cta`. -/
  | barrier (cta : Nat)
  deriving DecidableEq, Repr

/-- Memory: blocks by number, the next fresh number for a block of the launch (at least 1; an
`alloca`'s block is numbered from its thread instead, `Mem.fresh`), and the trace of the run's
accesses and barriers, newest first (ghost state: the semantics never reads it). -/
structure Mem where
  /-- Builds a memory from its blocks, next fresh number and trace. -/
  mk ::
  /-- The blocks, by number (none by default). -/
  blocks : Nat → Option Block := fun _ => none
  /-- The next fresh number for a block of the launch (1 by default). -/
  next : Nat := 1
  /-- The trace of accesses and barriers, newest first (empty by default). -/
  trace : List Event := []

/-- The `n` little-endian bytes of the number `x`. -/
def leBytes (n x : Nat) : List MemByte :=
  (List.range n).map fun i => .byte (BitVec.ofNat 8 (x >>> (8 * i)))

/-- The number little-endian data bytes hold (`none` if a byte is not data). -/
def ofLeBytes : List MemByte → Option Nat
  | [] => some 0
  | .byte b :: bs => (ofLeBytes bs).map (b.toNat + 256 * ·)
  | _ :: _ => none

namespace Layout

/-- The bytes a value of type `t` occupies in memory: the store size of a scalar or vector, the
allocation size (padding included) of an aggregate. -/
def stored (l : Layout) : Ty → Nat
  | t@(.arr _ _) | t@(.struct _) => l.size t
  | t => l.storeSize t

mutual
  /-- The bytes of value `v` of type `t`, `l.stored t` of them (`encode_length`); `none` if `v`
  is not a value of `t`, or for vectors of elements that are not scalars (`Ty.scalar`) or are
  narrower than a byte, which the semantics does not store. -/
  def encode (l : Layout) : Ty → Val → Option (List MemByte)
    | t, .poison => some (List.replicate (l.stored t) .poison)
    | t, .undef => some (List.replicate (l.stored t) .undef)
    | .int w, .bits w' b => if w' = w then some (leBytes ((w + 7) / 8) b.toNat) else none
    | .fp f, .bits w b => if w = f.fmt.bitWidth then some (leBytes (w / 8) b.toNat) else none
    | .ptr a, .ptr p => some ((List.range (l.storeSize (.ptr a))).map (.ptr p ·))
    | .vec n t, .vec xs =>
      if xs.length = n ∧ t.scalar ∧ l.scalarBits t % 8 = 0 then l.encodeAll t xs 0 else none
    | .arr n t, .agg xs => if xs.length = n then l.encodeAll t xs (l.size t) else none
    | .struct fs, .agg xs =>
      (l.encodeFields 0 fs xs).map (· ++ List.replicate (l.size (.struct fs) - l.fieldsEnd 0 fs)
        .undef)
    | _, _ => none

  /-- The bytes of elements `xs` of type `t`, each padded to `stride` bytes. -/
  def encodeAll (l : Layout) (t : Ty) : List Val → Nat → Option (List MemByte)
    | [], _ => some []
    | x :: xs, stride => do
      let b ← l.encode t x
      let rest ← l.encodeAll t xs stride
      return b ++ List.replicate (stride - b.length) .undef ++ rest

  /-- The bytes of struct fields `fs` with values `xs`, laid out from offset `off`, with the
  padding before each field. -/
  def encodeFields (l : Layout) (off : Nat) : List Ty → List Val → Option (List MemByte)
    | [], [] => some []
    | t :: ts, x :: xs => do
      let o := roundUp off (l.align t)
      let b ← l.encode t x
      let rest ← l.encodeFields (o + l.size t) ts xs
      return List.replicate (o - off) .undef ++ b ++ List.replicate (l.size t - b.length) .undef ++
        rest
    | _, _ => none
end

/-- A scalar of `w` bits from its bytes: poison if a byte is poison, else `undef` if a byte is
undefined, else the number; poison if it does not fit in `w` bits, a nonzero padding bit (LangRef,
"load", makes the bits of its byte poison; here the whole scalar); `none` for pointer bytes. -/
def scalarOf (w : Nat) (bs : List MemByte) : Option Val :=
  if bs.contains .poison then some .poison
  else if bs.contains .undef then some .undef
  else (ofLeBytes bs).map fun n => if n < 2 ^ w then .bits w (BitVec.ofNat w n) else .poison

/-- A pointer from its bytes: poison and undefined bytes as for scalars, the bytes of one
pointer in order, or zero bytes (null); `none` otherwise. -/
def ptrOf (bs : List MemByte) : Option Val :=
  if bs.contains .poison then some .poison
  else if bs.contains .undef then some .undef
  else match bs with
    | .ptr p 0 :: _ =>
      if bs = (List.range bs.length).map (.ptr p ·) then some (.ptr p) else none
    | _ => if bs.all (· == .byte 0) then some (.ptr ⟨0, 0⟩) else none

/-- The `n` bytes of `bs` from position `o`. -/
def slice (bs : List MemByte) (o n : Nat) : List MemByte := (bs.drop o).take n

/-- `n` elements that `dec` reads from `k` bytes each, at stride `stride` from offset `o` (the
elements of a vector or an array, `dec` being `decode` at their type and `k` their store size).
By structural recursion on `n`. -/
def decodeAll (dec : List MemByte → Option Val) (k : Nat) :
    Nat → Nat → Nat → List MemByte → Option (List Val)
  | 0, _, _, _ => some []
  | n + 1, stride, o, bs => do
    let x ← dec (slice bs o k)
    let rest ← decodeAll dec k n stride (o + stride) bs
    return x :: rest

mutual
  /-- The value of type `t` that bytes `bs` hold (`none` when they hold none). By structural
  recursion on `t`, with `decodeFields` on the fields of a struct, so the kernel evaluates it
  (well-founded recursion would not unfold under `decide +kernel`). -/
  def decode (l : Layout) : Ty → List MemByte → Option Val
    | .int w, bs => scalarOf w bs
    | .fp f, bs => scalarOf f.fmt.bitWidth bs
    | .ptr _, bs => ptrOf bs
    | .vec n t, bs =>
      if t.scalar ∧ l.scalarBits t % 8 = 0 then
        (decodeAll (l.decode t) (l.stored t) n (l.scalarBits t / 8) 0 bs).map .vec
      else none
    | .arr n t, bs => (decodeAll (l.decode t) (l.stored t) n (l.size t) 0 bs).map .agg
    | .struct fs, bs => (l.decodeFields 0 fs bs).map .agg
    | _, _ => none
  termination_by structural t => t

  /-- Struct fields `fs` laid out from offset `off`. By structural recursion on `fs`. -/
  def decodeFields (l : Layout) (off : Nat) : List Ty → List MemByte → Option (List Val)
    | [], _ => some []
    | t :: ts, bs => do
      let o := roundUp off (l.align t)
      let x ← l.decode t (slice bs o (l.stored t))
      let rest ← l.decodeFields (o + l.size t) ts bs
      return x :: rest
  termination_by structural fs => fs
end

/-- The zero value of a type (`zeroinitializer`). -/
def zero (l : Layout) : Ty → Option Val
  | .int w => some (.bits w 0)
  | .fp f => some (.bits f.fmt.bitWidth 0)
  | .ptr _ => some (.ptr ⟨0, 0⟩)
  | .vec n t => (l.zero t).map fun z => .vec (List.replicate n z)
  | .arr n t => (l.zero t).map fun z => .agg (List.replicate n z)
  | .struct fs => (fs.mapM fun t => l.zero t).map .agg
  | _ => none

end Layout

/-- The `n` bytes of block `b` from offset `o`. -/
def Block.read (b : Block) (o n : Nat) : List MemByte :=
  (List.range n).map fun i => b.bytes (o + i)

/-- Block `b` with bytes `bs` written from offset `o`. -/
def Block.put (b : Block) (o : Nat) (bs : List MemByte) : Block :=
  { b with
    bytes := fun i => if o ≤ i ∧ i < o + bs.length then bs.getD (i - o) .poison else b.bytes i }

/-- The bytes of a list by position, as a binary tree (a Braun tree): the root holds position
0, and position `j + 1` is at position `j / 2` of the left subtree if `j` is even and of the
right one if `j` is odd. A read walks one path, of about `log₂` of the list's length nodes,
where `List.getD` walks the list up to the position. -/
inductive ByteTree where
  /-- No bytes: every position reads `undef`. -/
  | nil
  /-- Byte `x` at position 0, and the trees of the positions `j + 1` above it with `j` even
  (`l`) and odd (`r`). -/
  | node (x : MemByte) (l r : ByteTree)

/-- The byte at position `i` of a tree, `undef` past its bytes. -/
def ByteTree.get : ByteTree → Nat → MemByte
  | .nil, _ => .undef
  | .node x l r, i => match i with
    | 0 => x
    | j + 1 => if j % 2 = 0 then l.get (j / 2) else r.get (j / 2)

/-- The elements of `xs` at even positions and at odd positions, in order. -/
def ByteTree.halves : List MemByte → List MemByte × List MemByte
  | [] => ([], [])
  | x :: xs => (x :: (halves xs).2, (halves xs).1)

/-- The tree of the bytes `xs`, to depth `n` (`xs.length` is enough, `ByteTree.get_ofList`). -/
def ByteTree.ofList : Nat → List MemByte → ByteTree
  | 0, _ => .nil
  | _ + 1, [] => .nil
  | n + 1, x :: xs => .node x (ofList n (halves xs).1) (ofList n (halves xs).2)

/-- The bytes of a block whose first bytes are `init` and the others undefined: position `i`
of the tree of `init`, which is `init.getD i .undef` (`ByteTree.bytesOf_eq`). The kernel reads
a byte along one path of the tree; compiled code reads the list (`ByteTree.bytesOf_csimp`). -/
def ByteTree.bytesOf (init : List MemByte) : Nat → MemByte :=
  fun i => (ofList init.length init).get i

/-- `init.getD i .undef`, the bytes `ByteTree.bytesOf init` stands for, which compiled code runs
for it; it is private, as only `ByteTree.bytesOf_csimp` names it. -/
private def ByteTree.bytesOfList (init : List MemByte) : Nat → MemByte :=
  fun i => init.getD i .undef

/-- **Splitting a list by the parity of positions**, for every list `xs`, position `k` and
default `d`: element `k` of the even positions is element `2 * k` of `xs`, and of the odd ones
element `2 * k + 1`. -/
theorem ByteTree.halves_getD : ∀ (xs : List MemByte) (k : Nat) (d : MemByte),
    (halves xs).1.getD k d = xs.getD (2 * k) d ∧ (halves xs).2.getD k d = xs.getD (2 * k + 1) d
  | [], _, _ => by simp [halves]
  | x :: xs, k, d => by
    refine ⟨?_, ?_⟩
    · cases k with
      | zero => rfl
      | succ k =>
        rw [show 2 * (k + 1) = (2 * k + 1) + 1 by omega, List.getD_cons_succ]
        exact (halves_getD xs k d).2
    · rw [List.getD_cons_succ]
      exact (halves_getD xs k d).1

/-- **The lengths of the two halves**, for every list `xs`: the even positions are
`(xs.length + 1) / 2`, the odd ones `xs.length / 2`. -/
theorem ByteTree.halves_length : ∀ xs : List MemByte,
    (halves xs).1.length = (xs.length + 1) / 2 ∧ (halves xs).2.length = xs.length / 2
  | [] => by simp [halves]
  | x :: xs => by
    obtain ⟨h1, h2⟩ := halves_length xs
    refine ⟨?_, ?_⟩
    · show (halves xs).2.length + 1 = (xs.length + 1 + 1) / 2
      omega
    · exact h1

/-- **A tree reads its list**, for every depth `n` at least the list's length, list `xs` and
position `i`: position `i` of `ByteTree.ofList n xs` is `xs.getD i .undef`. -/
theorem ByteTree.get_ofList : ∀ {n : Nat} {xs : List MemByte}, xs.length ≤ n →
    ∀ i, (ofList n xs).get i = xs.getD i .undef
  | 0, xs, h, i => by
    rw [List.eq_nil_of_length_eq_zero (by omega : xs.length = 0)]
    rfl
  | _ + 1, [], _, _ => rfl
  | n + 1, x :: xs, h, i => by
    obtain ⟨h1, h2⟩ := halves_length xs
    have hl : xs.length ≤ n := by simp only [List.length_cons] at h; omega
    cases i with
    | zero => rfl
    | succ j =>
      simp only [ofList, get, List.getD_cons_succ]
      split
      · rw [get_ofList (by omega), (halves_getD xs (j / 2) .undef).1]
        congr 1; omega
      · rw [get_ofList (by omega), (halves_getD xs (j / 2) .undef).2]
        congr 1; omega

/-- **The bytes of a block from `init`**, for every list `init`: `ByteTree.bytesOf init` reads
position `i` as `init.getD i .undef`, the first bytes `init` and the others undefined. -/
@[simp] theorem ByteTree.bytesOf_eq (init : List MemByte) :
    bytesOf init = fun i => init.getD i .undef :=
  funext fun i => get_ofList (Nat.le_refl _) i

/-- `ByteTree.bytesOf` equals the private `fun init i => init.getD i .undef`
(`ByteTree.bytesOf_eq`), so compiled code runs the latter for it. -/
@[csimp] theorem ByteTree.bytesOf_csimp : @ByteTree.bytesOf = @ByteTree.bytesOfList :=
  funext fun init => bytesOf_eq init

namespace Mem

/-- The block a pointer points into, if it exists. -/
def block (m : Mem) (p : Ptr) : Option Block := m.blocks p.block

/-- `m` with block `b` set to `blk`. -/
def set (m : Mem) (b : Nat) (blk : Block) : Mem :=
  { m with blocks := fun c => if c = b then some blk else m.blocks c }

/-- Allocate a block of `size` bytes owned by `owner`, the first ones `init` and the others
undefined (`ByteTree.bytesOf init`, which is `fun i => init.getD i .undef` by
`ByteTree.bytesOf_eq`), live or not, with addresses `addr * align` and `gaddr * align` (wrapped
to the pointer widths of its space and of the generic space), at number `num`, or at the next
fresh number (which then increases) if `num` is `none`. Returns the memory and the block
number. -/
def alloc (l : Layout) (m : Mem) (space size align : Nat) (live readOnly : Bool) (owner : Owner)
    (addr gaddr : Nat) (init : List MemByte := []) (num : Option Nat := none) : Mem × Nat :=
  let blk : Block := { space, size, live, readOnly, owner, bytes := ByteTree.bytesOf init,
                       addr := addr * align % 2 ^ (l.ptr space).1,
                       gaddr := gaddr * align % 2 ^ (l.ptr 0).1 }
  match num with
  | none => ({ m.set m.next blk with next := m.next + 1 }, m.next)
  | some b => (m.set b blk, b)

/-- `alloc` at the next fresh number, unsupported if that number has a block (a caller's block
from `next` on): an allocation of the launch never replaces a block. -/
def allocNext (l : Layout) (m : Mem) (space size align : Nat) (live readOnly : Bool)
    (owner : Owner) (addr gaddr : Nat) (init : List MemByte := []) : Except Fault (Mem × Nat) :=
  if (m.blocks m.next).isSome then throw (.unsupported "launch block number in use")
  else pure (m.alloc l space size align live readOnly owner addr gaddr init)

/-- The number of the block that an `alloca` at step `k` of thread `n` makes: numbered from the
thread and its step, above the launch's blocks. No step
changes `next`, so the number does not depend on the order in which threads take steps. -/
def fresh (m : Mem) (n k : Nat) : Nat := m.next + Nat.pair n k

/-- The address of `p` as a pointer of address space `a`: its block's address in its own space
or (for `a = 0`) in the generic space, plus the offset, wrapped to the pointer width; null is 0.
A pointer into a block of another non-generic space has no address in space `a`. -/
def addr (l : Layout) (m : Mem) (a : Nat) (p : Ptr) : Except Fault Nat :=
  if p.block = 0 then pure ((p.off % 2 ^ (l.ptr a).1).toNat)
  else match m.block p with
    | none => throw (.ub "pointer to no block")
    | some b =>
      let base := if a = b.space then b.addr else b.gaddr
      if a = b.space ∨ a = 0 then pure (((base : Int) + p.off) % 2 ^ (l.ptr a).1).toNat
      else throw (.unsupported s!"address of a space-{b.space} pointer in space {a}")

/-- Check an access by thread `w` of `n` bytes at `p` with alignment `align` through a pointer of
space `a`: the block is live, its owner admits `w`, the bytes lie within it, the address is
aligned. Returns the block and the offset. -/
def check (l : Layout) (m : Mem) (w : Who) (a : Nat) (p : Ptr) (n : Nat) (align : Option Nat) :
    Except Fault (Block × Nat) := do
  let some b := m.block p | throw (.ub "access to no block")
  unless b.live do throw (.ub "access to a dead block")
  unless b.owner.admits w do throw (.ub "access to another thread's or block's memory")
  unless 0 ≤ p.off ∧ p.off + n ≤ b.size do throw (.ub "access out of bounds")
  let ad ← m.addr l a p
  if let some al := align then
    unless ad % al = 0 do throw (.ub "misaligned access")
  return (b, p.off.toNat)

/-- Load by thread `w` of a value of type `t` from `p` (a pointer of space `a`), after `check`;
unsupported if the bytes hold no value of `t`. -/
def load (l : Layout) (m : Mem) (w : Who) (a : Nat) (t : Ty) (p : Ptr) (align : Option Nat) :
    Except Fault Val := do
  let n := l.stored t
  let (b, o) ← m.check l w a p n align
  match l.decode t (b.read o n) with
  | some v => return v
  | none => throw (.unsupported "load of bytes that hold no value of the type")

/-- Write by thread `w` of bytes `bs` at `p` (a pointer of space `a`, alignment `align`). -/
def write (l : Layout) (m : Mem) (w : Who) (a : Nat) (p : Ptr) (bs : List MemByte)
    (align : Option Nat) : Except Fault Mem := do
  let (b, o) ← m.check l w a p bs.length align
  if b.readOnly then throw (.ub "store to read-only memory")
  return m.set p.block (b.put o bs)

/-- `m` with event `e` recorded in its trace. -/
def log (m : Mem) (e : Event) : Mem := { m with trace := e :: m.trace }

/-- Store by thread `w` of value `v` of type `t` at `p` (a pointer of space `a`), recorded as a
write of the bytes it writes, by an `atomicrmw` of operation `op` if `atomic = some op`. -/
def store (l : Layout) (m : Mem) (w : Who) (a : Nat) (t : Ty) (v : Val) (p : Ptr)
    (align : Option Nat) (atomic : Option RmwOp := none) : Except Fault Mem := do
  let some bs := l.encode t v | throw (.unsupported "store of a value not of the type")
  return (← m.write l w a p bs align).log (.access ⟨w, p, bs.length, true, atomic, false⟩)

end Mem

end MojoProof.Sem
