import Mathlib.Order.BoundedOrder.Basic

/-!
# The signature of a GPU machine

What the core knows of a machine: the types and functions of a `Sig`, and the shapes of its trace,
which are the same for every machine. A thread is running, waiting at a collective call, or
returned (`Status`); an agent is a thread of the launch or an issued asynchronous job (`Agent`);
an access reads, reads frozen bytes, writes, or updates (`Kind`) an interval of a buffer through
a proxy (`Access`); and a trace event is an access, a rendezvous, a release or an acquire of a
phase of a synchronization object, or a proxy fence (`Event`).

`Sig` has a field for every machine constant (the level instances and their members, the memory
spaces and their homes, the proxies), so no definition of the core fixes one, and a field of
decidable equality for each type that the race check, joins and checks compare. The bytes of an
access are derived through the machine's `Sig.place` (`Access.locs`), and two accesses conflict
when they share a byte, one of them writes and the machine does not exempt the pair
(`Access.conflict`). The race check is in GPUProof/Race.lean, the runs of a machine in
GPUProof/Run.lean; docs/proofs/core.md says where the Lean definitions depart from the design.
-/

namespace GPUProof

/-- A thread's status: running as thread `t`, waiting at collective call `call` (with the thread
`t` as it was before the call), or returned. -/
inductive Status (T C : Type) where
  /-- Running as thread `t`. -/
  | run (t : T)
  /-- Waiting at collective call `call`, with the thread `t` as it was before the call. -/
  | wait (t : T) (call : C)
  /-- Returned. -/
  | done
  deriving DecidableEq

/-- Who steps: a thread of the launch, or an issued asynchronous job. -/
inductive Agent (Tid Job : Type) where
  /-- Thread `t` of the launch. -/
  | thread (t : Tid)
  /-- The issued asynchronous job `j`. -/
  | job (j : Job)
  deriving DecidableEq

/-- What an access does to its bytes. -/
inductive Kind (Op : Type) where
  /-- A read. -/
  | read
  /-- A read of bytes that no write may touch during the launch, before or after it. -/
  | frozen
  /-- A write. -/
  | write
  /-- A read-modify-write by operation `op` whose result is unused; the machine may exempt pairs of
  them from the race check. -/
  | rmw (op : Op)
  /-- A read-modify-write by operation `op` whose result is used: it conflicts like a write. -/
  | rmwRet (op : Op)
  deriving DecidableEq

/-- Kind `k` writes its bytes: a write or a read-modify-write (`rmw` or `rmwRet`); a read and a
frozen read do not. -/
def Kind.writes {Op : Type} : Kind Op → Bool
  | .write | .rmw _ | .rmwRet _ => true
  | .read | .frozen => false

/-- One access by agent `who` to `len` bytes of buffer `buf` from offset `off`, through proxy
`proxy`. The bytes themselves are derived through the machine's `place` (`Access.locs`). -/
structure Access (A Buf Op Proxy : Type) where
  /-- The access by `who` to `len` bytes of `buf` from `off`, of kind `kind`, through `proxy`, for
  every type of agents, buffers, operations and proxies. -/
  mk ::
  /-- The agent that accesses. -/
  who : A
  /-- The buffer accessed. -/
  buf : Buf
  /-- The offset of the first byte accessed in `buf`. -/
  off : Int
  /-- The number of bytes accessed, from `off` on. -/
  len : Nat
  /-- What the access does to its bytes. -/
  kind : Kind Op
  /-- The proxy the access goes through. -/
  proxy : Proxy
  deriving DecidableEq

/-- A trace event over agents `A`, buffers `Buf`, operations `Op`, proxies `Proxy` and
synchronization objects `Obj`. -/
inductive Event (A Buf Op Proxy Obj : Type) where
  /-- Access `a`. -/
  | access (a : Access A Buf Op Proxy)
  /-- A rendezvous of `members` at object `o`: it lies on the program order of every member. -/
  | sync (o : Obj) (members : List A)
  /-- Agent `who` releases phase `ph` of synchronization object `o`. -/
  | rel (who : A) (o : Obj) (ph : Nat)
  /-- Agent `who` acquires phase `ph` of object `o`, after every earlier release of that phase. -/
  | acq (who : A) (o : Obj) (ph : Nat)
  /-- Agent `who`'s proxy fence: on a happens-before path, it orders an access through proxy `p`
  before an access through proxy `q`. -/
  | fence (who : A) (p q : Proxy)
  deriving DecidableEq

/-- The agents on whose program order event `e` lies: the agent of an access, a release, an
acquire or a fence, and every member of a rendezvous. -/
def Event.agents {A Buf Op Proxy Obj : Type} : Event A Buf Op Proxy Obj → List A
  | .access a => [a.who]
  | .sync _ ms => ms
  | .rel who _ _ | .acq who _ _ | .fence who _ _ => [who]

/-- The access of event `e`, if `e` is an access. -/
def Event.access? {A Buf Op Proxy Obj : Type} :
    Event A Buf Op Proxy Obj → Option (Access A Buf Op Proxy)
  | .access a => some a
  | _ => none

/-- An event, if any, whose access is `a` is the access `a`, for every event type. -/
theorem Event.bind_access?_eq_some {A Buf Op Proxy Obj : Type}
    {o : Option (Event A Buf Op Proxy Obj)} {a : Access A Buf Op Proxy} :
    o.bind Event.access? = some a ↔ o = some (.access a) := by
  rcases o with _ | (_ | _ | _ | _ | _) <;> simp [Event.access?]

/-- The law on a placement `place` of offsets of buffers at bytes, for all types of buffers and
bytes: different offsets of buffers are different bytes, so two offsets are one byte only when
they are one offset of one buffer. Under it two accesses share a byte exactly when they are of one
buffer and their intervals of offsets meet (`GPUProof.Access.meets_iff`); a machine gives it as the
field `GPUProof.Sig.placeInj`. -/
abbrev PlaceInj {Buf Loc : Type} (place : Buf → Int → Loc) : Prop :=
  ∀ {b b' : Buf} {i j : Int}, place b i = place b' j → b = b' ∧ i = j

/-- The signature of a GPU machine: its launches, agents and levels, its memory, its programs and
values, its states and steps, the caller's checks and the launch boundary, and decidable equality
on the types that the race check, joins and checks compare. -/
structure Sig where
  /-- The machine with these fields. -/
  mk ::
  /-- A launch: what fixes the threads and the level instances. -/
  Launch : Type
  /-- A thread id. -/
  Tid : Type
  /-- An asynchronous job (`Empty` for a machine without engines). -/
  Job : Type
  /-- Every thread of a launch, once. -/
  threads : Launch → List Tid
  /-- A level, from the thread up (lane, warp, block, cluster, grid). -/
  Level : Type
  /-- The order of the levels, from the thread up. -/
  [order : LinearOrder Level]
  /-- `⊥` is the level of one thread, `⊤` the whole launch. -/
  [bounds : BoundedOrder Level]
  /-- One instance of one level: a warp, a block, a cluster. -/
  Gid : Type
  /-- The instance of a level that a thread of a launch lies in. -/
  group : Launch → Level → Tid → Gid
  /-- The level of an instance. -/
  levelOf : Gid → Level
  /-- The threads of an instance, in order (a partial last warp is shorter). -/
  members : Launch → Gid → List Tid
  /-- A memory space. -/
  Space : Type
  /-- The level whose every instance has its own copy of a space. -/
  home : Space → Level
  /-- One byte of memory. -/
  Loc : Type
  /-- The space of a byte. -/
  space : Loc → Space
  /-- A number for each byte (`0` by default), by which `kept` sorts the bytes it compares: any
  numbering gives the same check (`kept_iff`), and one that gives different bytes different
  numbers makes it fast. -/
  key : Loc → Nat := fun _ => 0
  /-- A byte's value. -/
  Byte : Type
  /-- A buffer: a block, an allocation, a parameter copy. -/
  Buf : Type
  /-- Byte `i` of a buffer. -/
  place : Buf → Int → Loc
  /-- A proof of the law on `place` (`GPUProof.PlaceInj`), when the machine gives one (`none` by
  default). With it the race check compares two accesses' buffers and offsets in place of their
  bytes (`Sig.share`). -/
  placeInj : Option (PLift (PlaceInj place)) := none
  /-- A buffer's own state: size, liveness, owner, flags, addresses. -/
  Meta : Type
  /-- A memory, as observations and resources read it. -/
  Bytes : Type
  /-- The value of a byte of a memory, if it has one. -/
  byteAt : Bytes → Loc → Option Byte
  /-- The state of a buffer of a memory, if it has one. -/
  metaAt : Bytes → Buf → Option Meta
  /-- A read-modify-write operation. -/
  Op : Type
  /-- Updates by the operation commute. -/
  commutes : Op → Bool
  /-- What an update by the operation leaves, from the old bytes and the operand bytes, if
  defined. -/
  combine : Op → List Byte → List Byte → Option (List Byte)
  /-- A proxy (`Unit` for a machine with one). -/
  Proxy : Type
  /-- The race exemption: two updates the machine lets go unordered. -/
  exempt : Access (Agent Tid Job) Buf Op Proxy → Access (Agent Tid Job) Buf Op Proxy → Bool
  /-- A synchronization object: a block's barrier, a split-phase barrier, a job. -/
  Obj : Type
  /-- A program. -/
  Prog : Type
  /-- A value: an argument, an operand, a result. -/
  Val : Type
  /-- The caller's memory. -/
  Mem : Type
  /-- The bytes of the caller's memory. -/
  memBytes : Mem → Bytes
  /-- What a launch leaves open: addresses and float freedoms. -/
  Choice : Type
  /-- A float site. -/
  FloatSite : Type
  /-- The choice at each float site. -/
  site : Choice → FloatSite → Nat
  /-- A state of a launch. -/
  State : Type
  /-- A thread's own state. -/
  Thread : Type
  /-- Where a thread stands: a function and a position, a program counter. -/
  Site : Type
  /-- A collective call. -/
  Call : Type
  /-- A collective kind. -/
  CollKind : Type
  /-- The kind of a call. -/
  kindOf : Call → CollKind
  /-- The operands of a call. -/
  operandsOf : Call → List Val
  /-- Where a thread stands, if it stands somewhere. -/
  siteOf : Thread → Option Site
  /-- The level whose instances a kind's calls join. -/
  level : CollKind → Level
  /-- A completed call of the kind orders memory. -/
  orders : CollKind → Bool
  /-- A fault. -/
  Fault : Type
  /-- The launch of a state. -/
  launchOf : State → Launch
  /-- The status of a thread at a state. -/
  status : State → Tid → Status Thread Call
  /-- The jobs issued at a state. -/
  jobs : State → List Job
  /-- An issued job has landed. -/
  landed : State → Job → Bool
  /-- The memory of a state. -/
  bytes : State → Bytes
  /-- The events logged so far, oldest first; a ghost: no step reads it. -/
  trace : State → List (Event (Agent Tid Job) Buf Op Proxy Obj)
  /-- What an agent's next step would log: its accesses and its own `rel`, `acq` and `fence`
  events. -/
  pending : State → Agent Tid Job → List (Event (Agent Tid Job) Buf Op Proxy Obj)
  /-- What a fire at the thread's call would log, if it completes. -/
  firePending : State → Tid → List (Event (Agent Tid Job) Buf Op Proxy Obj)
  /-- The slots an agent's next step may read: the bytes its pending reads name, and the state of
  every buffer it names or would allocate. -/
  reads : State → Agent Tid Job → List (Loc ⊕ Buf)
  /-- A waiting thread resumed with the result of its call, if any. -/
  resume : Thread → Option Val → Thread
  /-- The start of a launch of a program on arguments, a caller's memory and a choice. -/
  start : Prog → Launch → List Val → Mem → Choice → Except Fault State
  /-- An agent's step: a fault, no step (`none`), or the next state. -/
  advance : State → Agent Tid Job → Except Fault (Option State)
  /-- The completion of the collective call a thread waits at: a fault, no completion (`none`), or
  the next state. -/
  fire : State → Tid → Except Fault (Option State)
  /-- Equal up to the order of independent trace events. -/
  Same : State → State → Prop
  /-- Equal in everything the agent's next step reads. -/
  Agree : State → Agent Tid Job → State → Prop
  /-- A step's effect: the agent's new status and memory operations. -/
  Delta : Type
  /-- A state with an agent's step effect applied. -/
  apply : State → Agent Tid Job → Delta → State
  /-- What a good start assumes of the caller's memory and the arguments. -/
  Closed : Mem → List Val → Prop
  /-- The arguments are checked for the program on the memory. -/
  ArgsOk : Prog → List Val → Mem → Prop
  /-- The program is checked for the launch. -/
  StartOk : Prog → Launch → Prop
  /-- The launch is valid. -/
  ValidLaunch : Launch → Prop
  /-- The start's own slots, each with its first owner: a thread or a level instance. -/
  launchCells : State → List ((Loc ⊕ Buf) × (Tid ⊕ Gid))
  /-- The caller's memory after a launch, from the caller's memory before it and a final state. -/
  endLaunch : Mem → State → Mem
  /-- Decidable equality of thread ids. -/
  [decTid : DecidableEq Tid]
  /-- Decidable equality of jobs. -/
  [decJob : DecidableEq Job]
  /-- Decidable equality of level instances. -/
  [decGid : DecidableEq Gid]
  /-- Decidable equality of bytes of memory. -/
  [decLoc : DecidableEq Loc]
  /-- Decidable equality of buffers. -/
  [decBuf : DecidableEq Buf]
  /-- Decidable equality of byte values. -/
  [decByte : DecidableEq Byte]
  /-- Decidable equality of buffer states. -/
  [decMeta : DecidableEq Meta]
  /-- Decidable equality of read-modify-write operations. -/
  [decOp : DecidableEq Op]
  /-- Decidable equality of proxies. -/
  [decProxy : DecidableEq Proxy]
  /-- Decidable equality of synchronization objects. -/
  [decObj : DecidableEq Obj]
  /-- Decidable equality of collective kinds. -/
  [decKind : DecidableEq CollKind]
  /-- Decidable equality of sites. -/
  [decSite : DecidableEq Site]
  /-- Decidable equality of values. -/
  [decVal : DecidableEq Val]

attribute [instance] Sig.order Sig.bounds Sig.decTid Sig.decJob Sig.decGid Sig.decLoc Sig.decBuf
  Sig.decByte Sig.decMeta Sig.decOp Sig.decProxy Sig.decObj Sig.decKind Sig.decSite Sig.decVal

namespace Sig

variable (S : Sig)

/-- An agent of machine `S`: a thread or a job. -/
abbrev Agent := GPUProof.Agent S.Tid S.Job

/-- An access of machine `S`. -/
abbrev Access := GPUProof.Access S.Agent S.Buf S.Op S.Proxy

/-- A trace event of machine `S`. -/
abbrev Event := GPUProof.Event S.Agent S.Buf S.Op S.Proxy S.Obj

end Sig

/-- The bytes of access `a` of machine `S`, in order: byte `a.off + i` of buffer `a.buf`, through
`S.place`, for each `i < a.len`. -/
def Access.locs (S : Sig) (a : S.Access) : List S.Loc :=
  (List.range a.len).map fun i : Nat => S.place a.buf (a.off + (i : Int))

/-- Accesses `a` and `b` of machine `S` conflict: they share a byte (`Access.locs`), one of them
writes (`Kind.writes`, so a result-used update writes), and `S.exempt a b` is `false`. -/
def Access.conflict (S : Sig) (a b : S.Access) : Bool :=
  (a.locs S).any (fun l => decide (l ∈ b.locs S)) && (a.kind.writes || b.kind.writes) &&
    !S.exempt a b

/-- Accesses `a` and `b` of machine `S` are of one buffer and their intervals of offsets, from
`off` to `off + len`, meet, for every machine: one comparison of buffers and four of numbers. -/
def Access.meets (S : Sig) (a b : S.Access) : Bool :=
  decide (a.buf = b.buf) && decide (a.off < b.off + b.len) && decide (b.off < a.off + a.len) &&
    decide (0 < a.len) && decide (0 < b.len)

/-- Whether accesses `a` and `b` of machine `S`, with bytes `L` and `L'`, share a byte, for every
machine: by their buffers and offsets (`Access.meets`) when `S` gives a proof that `place` is
injective (`Sig.placeInj`), and by comparing `L` with `L'` otherwise. The race check calls it with
the accesses' bytes (`Access.locs`), on which it decides whether they share one
(`Sig.share_iff`). -/
def Sig.share (S : Sig) (a b : S.Access) (L L' : List S.Loc) : Bool :=
  match S.placeInj with
  | some _ => Access.meets S a b
  | none => L.any fun l => L'.any fun l' => decide (l = l')

end GPUProof
