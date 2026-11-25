import GPUProof.Laminar
import GPUProof.Run
import MojoProof.Sem.Grid
import Std.Data.HashMap

/-!
# The definitions of MojoProof's signature

`sig`, MojoProof's machine as a machine of the core (`GPUProof.Sig`), and every definition of
MojoProof that it reaches above MojoProof/Sem/Grid.lean, so that the modules from
MojoProof/Sem/Spec.lean up can state a theorem with the core's predicates at `sig`.
MojoProof/Sem/Sig.lean has `sig`'s simp and transport lemmas, and docs/proofs/sig.md the table of
its fields.

* Decidable equality of LLVM types (`Ty.decEq`, so of intrinsics) and of values (`Val.decEq`), by
  structural recursion, since `deriving` does not apply to the nested types.
* Valid launches (`Launch.Valid`, with `Launch.maxGrid` and `Launch.maxBlock`).
* The accesses of a trace with their phases (`phases`) and the bytes of an access
  (`Access.bytes`).
* Traces and grids that are the same up to the order of independent events (`Trace.Same`,
  `Grid.Same`); the events a step would log (`Stmt.pending`, `Thread.pending`, `Grid.pending`)
  and those the completion of a collective call would log (`Grid.fired`); the shape of a block
  (`Block.shape`); the numbers a value or a scope names (`Val.NamesIn`, `Val.AllNamesIn`,
  `Scope.NamesIn`).
* The numbers a memory knows (`Mem.Known`) and the numbers its pointer bytes name
  (`Mem.BytesIn`).
* Agreement of blocks and of memories at the bytes a list of events reads (`Reads`,
  `Block.Agree`, `Mem.Agree`), and changes of memory (`Mem.Op`, `Mem.apply`, `Mem.run`).
* The parts of `sig` (`Access.kind`, `Access.toCore`, `Event.toCore`, `sigStatus`, `sigAgree`
  and the others) and `sig`.

Their theorems are in the modules that use them: those of valid launches in Spec.lean, of phases
and bytes in Race.lean, of pending events, sameness and names in Schedule.lean, of known numbers
and pointer bytes in Names.lean, and of agreement and changes of memory in Frame.lean.
-/

namespace MojoProof.LLVM

/-! ### Decidable equality of LLVM types and of intrinsics -/

mutual
/-- Decidable equality of LLVM types, by structural recursion on both types: `deriving` does not
apply to `Ty`, whose `struct` nests a list of types. -/
def Ty.decEq : (a b : Ty) → Decidable (a = b)
  | .void, .void | .label, .label | .metadata, .metadata => isTrue rfl
  | .int w, .int w' =>
    if h : w = w' then isTrue (h ▸ rfl) else isFalse fun e => h (by cases e; rfl)
  | .fp t, .fp t' =>
    if h : t = t' then isTrue (h ▸ rfl) else isFalse fun e => h (by cases e; rfl)
  | .ptr a, .ptr a' =>
    if h : a = a' then isTrue (h ▸ rfl) else isFalse fun e => h (by cases e; rfl)
  | .vec n t, .vec n' t' =>
    if h : n = n' then match Ty.decEq t t' with
      | isTrue h' => isTrue (by subst h; subst h'; rfl)
      | isFalse h' => isFalse fun e => h' (by cases e; rfl)
    else isFalse fun e => h (by cases e; rfl)
  | .arr n t, .arr n' t' =>
    if h : n = n' then match Ty.decEq t t' with
      | isTrue h' => isTrue (by subst h; subst h'; rfl)
      | isFalse h' => isFalse fun e => h' (by cases e; rfl)
    else isFalse fun e => h (by cases e; rfl)
  | .struct fs, .struct gs => match Ty.decEqList fs gs with
    | isTrue h => isTrue (h ▸ rfl)
    | isFalse h => isFalse fun e => h (by cases e; rfl)
  | .void, .int _ | .void, .fp _ | .void, .ptr _ | .void, .vec .. | .void, .arr ..
  | .void, .struct _ | .void, .label | .void, .metadata | .int _, .void | .int _, .fp _
  | .int _, .ptr _ | .int _, .vec .. | .int _, .arr .. | .int _, .struct _ | .int _, .label
  | .int _, .metadata | .fp _, .void | .fp _, .int _ | .fp _, .ptr _ | .fp _, .vec ..
  | .fp _, .arr .. | .fp _, .struct _ | .fp _, .label | .fp _, .metadata | .ptr _, .void
  | .ptr _, .int _ | .ptr _, .fp _ | .ptr _, .vec .. | .ptr _, .arr .. | .ptr _, .struct _
  | .ptr _, .label | .ptr _, .metadata | .vec .., .void | .vec .., .int _ | .vec .., .fp _
  | .vec .., .ptr _ | .vec .., .arr .. | .vec .., .struct _ | .vec .., .label
  | .vec .., .metadata | .arr .., .void | .arr .., .int _ | .arr .., .fp _ | .arr .., .ptr _
  | .arr .., .vec .. | .arr .., .struct _ | .arr .., .label | .arr .., .metadata
  | .struct _, .void | .struct _, .int _ | .struct _, .fp _ | .struct _, .ptr _
  | .struct _, .vec .. | .struct _, .arr .. | .struct _, .label | .struct _, .metadata
  | .label, .void | .label, .int _ | .label, .fp _ | .label, .ptr _ | .label, .vec ..
  | .label, .arr .. | .label, .struct _ | .label, .metadata | .metadata, .void
  | .metadata, .int _ | .metadata, .fp _ | .metadata, .ptr _ | .metadata, .vec ..
  | .metadata, .arr .. | .metadata, .struct _ | .metadata, .label => isFalse nofun

/-- Decidable equality of lists of LLVM types, with `Ty.decEq` on their elements. -/
def Ty.decEqList : (a b : List Ty) → Decidable (a = b)
  | [], [] => isTrue rfl
  | x :: xs, y :: ys => match Ty.decEq x y, Ty.decEqList xs ys with
    | isTrue h, isTrue h' => isTrue (h ▸ h' ▸ rfl)
    | isFalse h, _ => isFalse fun e => h (List.cons.inj e).1
    | _, isFalse h => isFalse fun e => h (List.cons.inj e).2
  | [], _ :: _ | _ :: _, [] => isFalse nofun
end

/-- Decidable equality of LLVM types, by `Ty.decEq`. -/
instance : DecidableEq Ty := Ty.decEq

deriving instance DecidableEq for Intrinsic

/-- Decidable equality of intrinsics, derived. -/
add_decl_doc instDecidableEqIntrinsic

end MojoProof.LLVM

namespace MojoProof.Sem

open LLVM Relation

/-! ### Decidable equality of values -/

mutual
/-- Decidable equality of values, by structural recursion on both values: `deriving` does not
apply to `Val`, whose `bits` carries a bit vector of its width and whose `vec` and `agg` nest
lists of values. -/
def Val.decEq : (a b : Val) → Decidable (a = b)
  | .bits w x, .bits w' y =>
    if h : w = w' then by
      subst h
      exact if hx : x = y then isTrue (hx ▸ rfl) else isFalse fun e => hx (by cases e; rfl)
    else isFalse fun e => h (by cases e; rfl)
  | .ptr p, .ptr q => if h : p = q then isTrue (h ▸ rfl) else isFalse fun e => h (by cases e; rfl)
  | .poison, .poison | .undef, .undef => isTrue rfl
  | .vec xs, .vec ys => match Val.decEqList xs ys with
    | isTrue h => isTrue (h ▸ rfl)
    | isFalse h => isFalse fun e => h (by cases e; rfl)
  | .agg xs, .agg ys => match Val.decEqList xs ys with
    | isTrue h => isTrue (h ▸ rfl)
    | isFalse h => isFalse fun e => h (by cases e; rfl)
  | .bits .., .ptr _ | .bits .., .poison | .bits .., .undef | .bits .., .vec _ | .bits .., .agg _
  | .ptr _, .bits .. | .ptr _, .poison | .ptr _, .undef | .ptr _, .vec _ | .ptr _, .agg _
  | .poison, .bits .. | .poison, .ptr _ | .poison, .undef | .poison, .vec _ | .poison, .agg _
  | .undef, .bits .. | .undef, .ptr _ | .undef, .poison | .undef, .vec _ | .undef, .agg _
  | .vec _, .bits .. | .vec _, .ptr _ | .vec _, .poison | .vec _, .undef | .vec _, .agg _
  | .agg _, .bits .. | .agg _, .ptr _ | .agg _, .poison | .agg _, .undef | .agg _, .vec _ =>
    isFalse nofun

/-- Decidable equality of lists of values, with `Val.decEq` on their elements. -/
def Val.decEqList : (a b : List Val) → Decidable (a = b)
  | [], [] => isTrue rfl
  | x :: xs, y :: ys => match Val.decEq x y, Val.decEqList xs ys with
    | isTrue h, isTrue h' => isTrue (h ▸ h' ▸ rfl)
    | isFalse h, _ => isFalse fun e => h (List.cons.inj e).1
    | _, isFalse h => isFalse fun e => h (List.cons.inj e).2
  | [], _ :: _ | _ :: _, [] => isFalse nofun
end

/-- Decidable equality of values, by `Val.decEq`. -/
instance : DecidableEq Val := Val.decEq

/-! ### Valid launches -/

/-- The largest grid, by dimension: `%nctaid` is at most `(2^31 - 1, 65535, 65535)` (PTX ISA,
`%nctaid`; the corpus's `range` attributes say the same). -/
def Launch.maxGrid : Dim → Nat
  | .x => 2 ^ 31 - 1
  | _ => 65535

/-- The largest block, by dimension: `%ntid` is at most `(1024, 1024, 64)` (PTX ISA, `%ntid`;
the corpus's `range` attributes say the same). -/
def Launch.maxBlock : Dim → Nat
  | .z => 64
  | _ => 1024

/-- A launch PTX accepts: every side of the grid and of the block is positive and at most the
maximum, and a block has at most 1024 threads. -/
structure Launch.Valid (L : Launch) : Prop where
  /-- Builds `Launch.Valid` from its five fields. -/
  mk ::
  /-- Every side of the grid is positive. -/
  grid_pos : ∀ d, 0 < L.grid d
  /-- Every side of the grid is at most `maxGrid`. -/
  grid_le : ∀ d, L.grid d ≤ maxGrid d
  /-- Every side of the block is positive. -/
  block_pos : ∀ d, 0 < L.block d
  /-- Every side of the block is at most `maxBlock`. -/
  block_le : ∀ d, L.block d ≤ maxBlock d
  /-- A block has at most 1024 threads. -/
  threads : volume L.block ≤ 1024

/-! ### Phases and bytes of accesses -/

section

open Std

/-- The accesses of trace `tr` (newest first), each with its phase, the number of barriers of its
block of threads before it; and those numbers after the whole trace, by block of threads. -/
def phases (tr : List Event) : List (Access × Nat) × HashMap Nat Nat :=
  tr.foldr (init := ([], ∅)) fun e p => match e with
    | .barrier k => (p.1, p.2.insert k (p.2.getD k 0 + 1))
    | .access a => ((a, p.2.getD a.who.cta 0) :: p.1, p.2)

/-- The bytes access `a` touches: block and offset. -/
def Access.bytes (a : Access) : List (Nat × Int) :=
  (List.range a.len).map fun i : Nat => (a.ptr.block, a.ptr.off + (i : Int))

end

/-! ### Pending events, sameness and names -/

/-- Traces `tr` and `tr'` (newest first) are the same up to the order of independent events:
`phases` lists the same accesses, each in the same phase, up to order, and counts the same number
of barriers of each block of threads. -/
def Trace.Same (tr tr' : List Event) : Prop :=
  (phases tr).1.Perm (phases tr').1 ∧ ∀ k, (phases tr).2.getD k 0 = (phases tr').2.getD k 0

/-- Grids `g` and `g'` are the same up to the order of independent trace events: the same
threads, blocks and next block number, and traces that are the same (`Trace.Same`). The
equivalence of schedule independence (T2 in docs/proofs/schedule.md). -/
def Grid.Same (g g' : Grid) : Prop :=
  g.threads = g'.threads ∧ g.mem.blocks = g'.mem.blocks ∧ g.mem.next = g'.mem.next ∧
    Trace.Same g.mem.trace g'.mem.trace

/-- The accesses that statement `st` would log in context `c` with scope `s`, newest first: for a
`load`, `store` or `atomicrmw` whose pointer operand evaluates to a pointer, its access (two for an
`atomicrmw`: its write, in front of its read), and nothing otherwise. -/
def _root_.MojoProof.LLVM.Stmt.pending (c : Ctx) (s : Scope) (st : Stmt) : List Event :=
  let acc (a : Nat) (p : Value) (t : Ty) (write : Bool) (op : Option RmwOp) (inv : Bool) :=
    match evalV s (.ptr a) p >>= Val.addr? with
    | .ok q => [Event.access ⟨c.who, q, c.prog.layout.stored t, write, op, inv⟩]
    | .error _ => []
  match st.inst with
  | .load _ t (.mk (.ptr a) p) _ => acc a p t false none (st.md.any (·.1 == "invariant.load"))
  | .store _ (.mk t _) (.mk (.ptr a) p) _ => acc a p t true none false
  | .atomicrmw _ op (.mk (.ptr a) p) (.mk t _) _ _ _ =>
    acc a p t true (some op) false ++ acc a p t false (some op) false
  | _ => []

/-- The accesses that the step of thread `t` on memory `m` would log, newest first: those of the
statement at its position (`Stmt.pending`), and none at a terminator. -/
def Thread.pending (c : Ctx) (t : Thread) (m : Mem) : List Event :=
  match t.frames with
  | f :: _ => match f.fn.blocks.find? (·.label == f.label) with
    | some b => match b.stmts[f.pc]? with
      | some st => st.pending c (c.scope m f t.k)
      | none => []
    | none => []
  | [] => []

/-- The events the step of thread `n` of grid `g` would log, newest first: its pending accesses
if it runs (`Thread.pending`), none otherwise. -/
def Grid.pending (c : Nat → Ctx) (g : Grid) (n : Nat) : List Event :=
  match g.threads[n]? with
  | some (.run t) => t.pending (c n) g.mem
  | _ => []

/-- The events the completion of the collective call thread `n` of grid `g` waits at would log:
one `.barrier` of `n`'s block of threads at a barrier, none otherwise. -/
def Grid.fired (L : Launch) (g : Grid) (n : Nat) : List Event :=
  match g.threads[n]? with
  | some (.wait _ .barrier _ _) => [.barrier (n / volume L.block)]
  | _ => []

/-- The space, size and addresses of a block: what evaluating an operand reads of it. -/
def Block.shape (b : Block) : Nat × Nat × Nat × Nat := (b.space, b.size, b.addr, b.gaddr)

mutual
  /-- Every pointer in value `v` (in vectors and aggregates too) names a block number of `S`. -/
  def Val.NamesIn (S : Nat → Prop) : Val → Prop
    | .ptr p => S p.block
    | .vec xs | .agg xs => Val.AllNamesIn S xs
    | _ => True

  /-- Every pointer in values `xs` names a block number of `S`. -/
  def Val.AllNamesIn (S : Nat → Prop) : List Val → Prop
    | [] => True
    | x :: xs => x.NamesIn S ∧ Val.AllNamesIn S xs
end

/-- Scope `s` names only block numbers of `S`: null's, its registers' and its globals'. -/
structure Scope.NamesIn (S : Nat → Prop) (s : Scope) : Prop where
  /-- Builds `Scope.NamesIn` from its three fields. -/
  mk ::
  /-- The null pointer's number 0 is in `S`. -/
  null : S 0
  /-- Every register's value names only numbers of `S`. -/
  regs : ∀ n v, s.regs n = some v → v.NamesIn S
  /-- Every global's pointer names a number of `S`. -/
  globals : ∀ g p, s.globals g = some p → S p.block

/-! ### Known numbers and pointer bytes -/

/-- Number `b` is below `next` or has a block in `m`: the numbers a closed grid names. -/
def Mem.Known (m : Mem) (b : Nat) : Prop := b < m.next ∨ (m.blocks b).isSome

/-- Every pointer byte below the size of a block of `m` names a number of `S`. -/
def Mem.BytesIn (S : Nat → Prop) (m : Mem) : Prop :=
  ∀ c b i p j, m.blocks c = some b → i < b.size → b.bytes i = .ptr p j → S p.block

/-! ### Agreement and changes of memory -/

/-- A read of `P` reads byte `i` of block `b`: a read access of `P` covers it. -/
def Reads (P : List Event) (b i : Nat) : Prop :=
  ∃ a, .access a ∈ P ∧ a.write = false ∧ a.ptr.block = b ∧ a.ptr.off ≤ (i : Int) ∧
    (i : Int) < a.ptr.off + a.len

/-- Blocks `x` and `y` agree for thread `w` at the bytes of `R`: the same shape, read-only flag
and owner, and, if the owner admits `w`, the same liveness and the same bytes at `R`. -/
structure Block.Agree (w : Who) (R : Nat → Prop) (x y : Block) : Prop where
  /-- The agreement from its five parts. -/
  mk ::
  /-- The same space, size and addresses (`Block.shape`). -/
  shape : x.shape = y.shape
  /-- The same read-only flag. -/
  readOnly : x.readOnly = y.readOnly
  /-- The same owner. -/
  owner : x.owner = y.owner
  /-- If the owner admits `w`, the same liveness. -/
  live : x.owner.admits w → x.live = y.live
  /-- If the owner admits `w`, the same byte at every offset of `R`. -/
  bytes : x.owner.admits w → ∀ i, R i → x.bytes i = y.bytes i

/-- The frame lemma's hypothesis: memories `m₁` and `m₂` have the same `next`, and at every number
of `S` both have no block or both have blocks that agree for thread `w` (`Block.Agree`) at the bytes
the reads of `P` read there. -/
structure Mem.Agree (w : Who) (S : Nat → Prop) (P : List Event) (m₁ m₂ : Mem) : Prop where
  /-- The agreement from `next` and `blocks`. -/
  mk ::
  /-- The same `next`. -/
  next : m₁.next = m₂.next
  /-- At every number of `S`, both memories have no block, or blocks that agree for `w`
  (`Block.Agree`) at the bytes that the reads of `P` read there. -/
  blocks : ∀ b, S b → Option.Rel (Block.Agree w (Reads P b)) (m₁.blocks b) (m₂.blocks b)

/-- A change of memory: bytes `bs` written into block `b` from offset `o` (if it exists), block
`b` set to `x`, block `b` made live or dead (`Mem.setLive`), or event `e` logged. -/
inductive Mem.Op
  /-- Bytes `bs` written into block `b` from offset `o`, if `b` has a block. -/
  | put (b o : Nat) (bs : List MemByte)
  /-- Block `b` set to `x`. -/
  | set (b : Nat) (x : Block)
  /-- Block `b` made live (`v = true`) or dead (`Mem.setLive`). -/
  | live (b : Nat) (v : Bool)
  /-- Event `e` logged. -/
  | log (e : Event)

/-- Memory `m` with change `op` applied. -/
def Mem.apply (m : Mem) : Mem.Op → Mem
  | .put b o bs => match m.blocks b with
    | some x => m.set b (x.put o bs)
    | none => m
  | .set b x => m.set b x
  | .live b v => m.setLive b v
  | .log e => m.log e

/-- Memory `m` with changes `ops` applied, first to last. -/
def Mem.run (m : Mem) (ops : List Mem.Op) : Mem := ops.foldl Mem.apply m

/-! ### The parts of `sig` -/

/-- The core's kind of access `a`: an update by the operation of an `atomicrmw`'s access, its
read and its write alike (`Stmt.pending` logs both); a write; a frozen read for a load with
`!invariant.load`; a read otherwise. -/
def Access.kind (a : Access) : GPUProof.Kind RmwOp :=
  match a.atomic with
  | some op => .rmw op
  | none => if a.write then .write else if a.invariant then .frozen else .read

/-- The number of the instance of level `l` that thread `n` of launch `L` lies in: the thread
itself (level 0); its warp's first thread (level 1, the base of `Grid.fire`'s shuffle lanes); its
block of threads (level 2); 0, the grid (level 3). -/
def Launch.groupNum (L : Launch) (l : Fin 4) (n : Nat) : Nat :=
  match l.val with
  | 0 => n
  | 1 => n - n % volume L.block % 32
  | 2 => n / volume L.block
  | _ => 0

/-- The threads of level instance `(l, i)` of launch `L`, in order: the threads of the launch
whose instance of level `l` is numbered `i` (`Launch.groupNum`). So thread `i` (level 0); the
lanes of the warp from thread `i` that lie in its block of threads (level 1, `Grid.fire`'s
shuffle lanes); the threads of block `i` (level 2, `Grid.fire`'s barrier group); every thread of
the launch (level 3, number 0); and none for a number that no thread of the launch has. -/
def Launch.members (L : Launch) (g : Fin 4 × Nat) : List Nat :=
  (List.range (volume L.grid * volume L.block)).filter fun n => L.groupNum g.1 n = g.2

/-- The level whose every instance has its own copy of address space `a`: PTX's shared memory
(3) is the block of threads', its local memory (5) the thread's; every other space is the
grid's. -/
def spaceHome (a : Nat) : Fin 4 :=
  if a = 3 then 2 else if a = 5 then 0 else 3

/-- The state of a block without its bytes. -/
structure BlockMeta where
  /-- The state of a block from its address space, size, liveness, read-only flag, owner and
  addresses. -/
  mk ::
  /-- The address space. -/
  space : Nat
  /-- The size in bytes. -/
  size : Nat
  /-- Whether the block is live. -/
  live : Bool
  /-- Whether the block is read-only. -/
  readOnly : Bool
  /-- The owner. -/
  owner : Owner
  /-- The address. -/
  addr : Nat
  /-- The generic address. -/
  gaddr : Nat
  deriving DecidableEq

/-- Decidable equality of the states of blocks without their bytes, derived. -/
add_decl_doc instDecidableEqBlockMeta

/-- The state of block `k` without its bytes: its address space, size, liveness, read-only flag,
owner, and its two addresses. -/
def Block.meta (k : Block) : BlockMeta :=
  ⟨k.space, k.size, k.live, k.readOnly, k.owner, k.addr, k.gaddr⟩

/-- The value of byte `i` of block `b` of blocks `bs`: none if there is no block `b` or `i` lies
outside its size. -/
def sigByteAt (bs : Nat → Option Block) (l : Nat × Int) : Option MemByte :=
  (bs l.1).bind fun k => if 0 ≤ l.2 ∧ l.2 < k.size then some (k.bytes l.2.toNat) else none

/-- What `atomicrmw op` leaves in its bytes, from the old bytes and the operand's bytes of one
length `k`: both read as integers of `8 * k` bits (`Layout.scalarOf`), combined by `rmw`, and stored
little-endian (`leBytes`, or `k` poison or undef bytes); none if the lengths differ, a list does
not hold an integer, or `rmw` faults. -/
def sigCombine (op : RmwOp) (old arg : List MemByte) : Option (List MemByte) :=
  if old.length = arg.length then
    match Layout.scalarOf (8 * old.length) old, Layout.scalarOf (8 * old.length) arg with
    | some x, some y => match rmw (8 * old.length) op x y with
      | .ok (.bits _ v) => some (leBytes old.length v.toNat)
      | .ok .poison => some (List.replicate old.length .poison)
      | .ok .undef => some (List.replicate old.length .undef)
      | _ => none
    | _, _ => none
  else none

/-- MojoProof's race exemption (`Access.conflict`) on the core's accesses: two updates by one
commuting `atomicrmw` operation (`RmwOp.commutes`, the signature's `commutes`) on the same bytes
(buffer, offset and length). Two updates by an operation that does not commute (`xchg`, `nand`,
`sub`, a float operation) are not exempt. -/
def sigExempt (a b : GPUProof.Access (GPUProof.Agent Nat Empty) Nat RmwOp Unit) : Bool :=
  match a.kind, b.kind with
  | .rmw op, .rmw op' =>
    op.commutes && op == op' && a.buf == b.buf && a.off == b.off && a.len == b.len
  | _, _ => false

/-- The level whose instances a call of intrinsic `i` joins: a barrier the block of threads, a
shuffle, `ldmatrix` and `mma` the warp, any other intrinsic (none waits) the thread. -/
def collLevel : Intrinsic → Fin 4
  | .barrier => 2
  | .shfl _ | .ldmatrix _ | .mma _ => 1
  | _ => 0

/-- Access `a` of a run as a core access: the access of its thread to its block from its
offset, of its length and kind (`Access.kind`), through the one proxy. -/
def Access.toCore (a : Access) : GPUProof.Access (GPUProof.Agent Nat Empty) Nat RmwOp Unit :=
  ⟨.thread a.who.thread, a.ptr.block, a.ptr.off, a.len, a.kind, ()⟩

/-- Event `e` of a run of launch `L` as a core event: an access is its core access
(`Access.toCore`); a barrier of block of threads `b` is the rendezvous of the threads of block
`b` at object `b`. -/
def Event.toCore (L : Launch) :
    Event → GPUProof.Event (GPUProof.Agent Nat Empty) Nat RmwOp Unit Nat
  | .access a => .access a.toCore
  | .barrier b => .sync b ((L.members (2, b)).map .thread)

/-- The status of thread `n` of grid `g` as the core's status: its run or wait, with the
intrinsic, arguments and declaration of its call; returned for a thread that has returned and
for a number with no thread. -/
def sigStatus (g : Grid) (n : Nat) : GPUProof.Status Thread (Intrinsic × List Val × Func) :=
  match g.threads[n]? with
  | some (.run t) => .run t
  | some (.wait t i args fn) => .wait t (i, args, fn)
  | some .done | none => .done

/-- The slots that the step of thread `n` of grid `g` may read, for a running thread: the bytes
of each of its pending reads (`Access.bytes`), the block of each pending access, and the block an
`alloca` of its step would get (`Mem.fresh`); none for a thread that does not run. -/
def sigReads (g : Grid) (c : Nat → Ctx) (n : Nat) : List ((Nat × Int) ⊕ Nat) :=
  match g.threads[n]? with
  | some (.run t) =>
    (t.pending (c n) g.mem).flatMap (fun
      | .access a => (if a.write then [] else a.bytes.map .inl) ++ [.inr a.ptr.block]
      | .barrier _ => []) ++ [.inr (g.mem.fresh (c n).who.thread t.k)]
  | _ => []

/-- States `s` and `s'` agree in what the step of thread `n` reads (`Grid.advance_agree`'s
premises): the same launch and contexts and the same status of `n`, and, if `n` runs `t`, a set
`S` of block numbers that holds every name of `t`'s scope and the block an `alloca` would get, at
which the memories agree for `n`'s pending accesses (`Mem.Agree`). -/
def sigAgree (s : Grid × Launch × (Nat → Ctx)) (n : Nat) (s' : Grid × Launch × (Nat → Ctx)) :
    Prop :=
  s.2 = s'.2 ∧ s.1.threads[n]? = s'.1.threads[n]? ∧
    ∀ t, s.1.threads[n]? = some (.run t) → ∃ S : Nat → Prop,
      (∀ f, t.frames.head? = some f → ((s.2.2 n).scope s.1.mem f t.k).NamesIn S) ∧
      S (s.1.mem.fresh (s.2.2 n).who.thread t.k) ∧
      s.1.mem.Agree (s.2.2 n).who S (t.pending (s.2.2 n) s.1.mem) s'.1.mem

/-- The launch's own blocks of grid `g`, each with its first owner: every block below `next`
owned by a block of threads (the level-2 instance) or by a thread. -/
def sigCells (g : Grid) : List (((Nat × Int) ⊕ Nat) × (Nat ⊕ (Fin 4 × Nat))) :=
  (List.range g.mem.next).filterMap fun b => (g.mem.blocks b).bind fun k => match k.owner with
    | .cta i => some (.inr b, .inr (2, i))
    | .thread n => some (.inr b, .inl n)
    | .all => none

/-- **MojoProof's signature**, for every program, kernel, launch, arguments, memory, address
choice and oracle: a state is a grid with its launch and contexts; a step is a grid step
(`Grid.advance`, `Grid.fire`) with them kept; the trace is the grid's trace, oldest first, as
core events (`Event.toCore`); every field is MojoProof's own definition (docs/proofs/sig.md).
A caller's memory is closed (`Closed`), for every argument list, when every pointer byte of its
blocks names a number below `next` or with a block (`Mem.BytesIn` at `Mem.Known`,
`Grid.confluent`'s premise); the start's check of the memory and the arguments is `ArgsOk`
(`Mem.checkClosed`). MojoProof has no launch boundary, so the caller's memory after a launch
(`endLaunch`) is the nearest one: the final blocks that every thread may access, the final `next`
and the caller's trace, without the blocks of a block of threads or of one thread. -/
@[reducible] def sig : GPUProof.Sig where
  Launch := Launch
  Tid := Nat
  Job := Empty
  threads L := List.range (volume L.grid * volume L.block)
  Level := Fin 4
  Gid := Fin 4 × Nat
  group L l n := (l, L.groupNum l n)
  levelOf := Prod.fst
  members := Launch.members
  Space := Nat
  home := spaceHome
  Loc := Nat × Int
  space _ := 0
  key l := Nat.pair l.1 (match l.2 with | .ofNat n => 2 * n | .negSucc n => 2 * n + 1)
  Byte := MemByte
  Buf := Nat
  place b i := (b, i)
  placeInj := some ⟨fun h => Prod.mk.inj h⟩
  Meta := BlockMeta
  Bytes := Nat → Option Block
  byteAt := sigByteAt
  metaAt bs b := (bs b).map Block.meta
  Op := RmwOp
  commutes := RmwOp.commutes
  combine := sigCombine
  Proxy := Unit
  exempt := sigExempt
  Obj := Nat
  Prog := Program × Func
  Val := Val
  Mem := Mem
  memBytes := Mem.blocks
  Choice := (Nat → Nat) × (Nat → Nat → Nat)
  FloatSite := Nat × Nat
  site ω p := ω.2 p.1 p.2
  State := Grid × Launch × (Nat → Ctx)
  Thread := Thread
  Site := String × Nat × Nat
  Call := Intrinsic × List Val × Func
  CollKind := Intrinsic
  kindOf := Prod.fst
  operandsOf k := k.2.1
  siteOf := Thread.at
  level := collLevel
  orders i := i matches .barrier
  Fault := Fault
  launchOf s := s.2.1
  status s := sigStatus s.1
  jobs _ := []
  landed _ j := nomatch j
  bytes s := s.1.mem.blocks
  trace s := (s.1.mem.trace.map (Event.toCore s.2.1)).reverse
  pending s a := match a with
    | .thread n => ((s.1.pending s.2.2 n).map (Event.toCore s.2.1)).reverse
    | .job j => nomatch j
  firePending s n := ((s.1.fired s.2.1 n).map (Event.toCore s.2.1)).reverse
  reads s a := match a with
    | .thread n => sigReads s.1 s.2.2 n
    | .job j => nomatch j
  resume := Thread.resume
  start P L args m ω := (Grid.start P.1 P.2 L args m ω.1 ω.2).map fun r => (r.1, L, r.2)
  advance s a := match a with
    | .thread n => (s.1.advance s.2.2 n).map (Option.map (·, s.2))
    | .job j => nomatch j
  fire s n := (s.1.fire s.2.1 s.2.2 n).map (Option.map (·, s.2))
  Same s s' := s.2 = s'.2 ∧ s.1.Same s'.1
  Agree s a s' := match a with
    | .thread n => sigAgree s n s'
    | .job j => nomatch j
  Delta := Status × List Mem.Op
  apply s a d := match a with
    | .thread n => ({ threads := s.1.threads.set! n d.1, mem := s.1.mem.run d.2 }, s.2)
    | .job j => nomatch j
  Closed m _ := m.BytesIn m.Known
  ArgsOk _ args m := m.checkClosed args = .ok ()
  StartOk P _ := P.2.check P.1.module = .ok ()
  ValidLaunch := Launch.Valid
  launchCells s := sigCells s.1
  endLaunch m s :=
    { m with blocks := fun b => (s.1.mem.blocks b).filter (·.owner == Owner.all),
             next := s.1.mem.next }

/-- `sig`'s `key` gives different bytes different numbers, for every two bytes: `Nat.pair` is
injective, and so is the offset's number (`2·n` for `n`, `2·n+1` for `-(n+1)`). `GPUProof.kept_iff`
holds for every numbering; this one makes `kept` at `sig` compare a byte written only with the
frozen bytes equal to it (docs/proofs/core.md, "`kept`'s cost"). -/
theorem sig_key_inj {l l' : sig.Loc} (h : sig.key l = sig.key l') : l = l' := by
  obtain ⟨b, i⟩ := l
  obtain ⟨b', i'⟩ := l'
  change Nat.pair b _ = Nat.pair b' _ at h
  obtain ⟨rfl, h⟩ := Nat.pair_eq_pair.mp h
  cases i <;> cases i' <;> simp at h <;> first | (subst h; rfl) | omega

end MojoProof.Sem
