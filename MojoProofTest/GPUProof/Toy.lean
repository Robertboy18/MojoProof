import GPUProof.Laminar
import GPUProof.Run
import Mathlib.Data.Bool.Basic
import Mathlib.Data.Nat.Pairing
import Mathlib.Order.Nat
import Mathlib.Order.WithBot

/-!
# A toy machine for the core

An honest signature (`toy`) that names no front end: a launch of `n` threads over a byte memory,
each running a list of instructions (`Ins`): a read or a write of an interval of a buffer through
one of two proxies, an update of one byte by addition with its result unused, a barrier of a
level instance, and a proxy fence. Its levels are `WithTop ℕ` (`Lvl`): `0` (`⊥`) the thread, `⊤`
the launch, and each `k` between them a level whose instances are blocks of consecutive threads.
A launch gives the number of threads and the width of each level from the thread up (`span`,
`groupOf`), so every number of levels is covered by one machine. Its bytes are a buffer and an
offset, and its synchronization objects are the barriers of the level instances (`barObj`), the
launch's being object `0`. The instance `Levels toy` holds at every launch, and every trace the
machine reaches from a launch is laminar for it (`reach_laminar`).

The tests run the machine at two unrelated sizes, 3 and 7 threads, with the toy schedule (`sched`,
`runFor`, whose states `runFor_reach` shows reachable):

* each thread writes its own byte, waits at the barrier and reads its neighbor's byte: the run
  ends with every thread returned, the bytes written, and a trace that `racy` passes and `kept`
  keeps; without the barrier `racy` refuses the trace; at 8 threads the kernel checks both
  (`ring_racy_kernel`, by `decide +kernel`);
* each thread writes its own byte through one proxy and reads it back through the other: with a
  fence between them `racy` passes the trace, without it `racy` refuses it;
* every thread adds `1` to one byte: the machine exempts the updates, and the byte ends at `n`;
* a write past the end of the buffer faults;
* the schedule's fuel bounds a run: 21 writes at one thread outlast `final`'s 20 steps, and
  `stopped` tells that run from one that stopped.

MojoProofTest/GPUProof/Race.lean tests the race check on traces of this machine,
MojoProofTest/GPUProof/Laminar.lean tests `GPUProof.HB.laminar_iff` on its runs with a level
between the thread and the launch, and MojoProofTest/GPUProof/Clean.lean proves `Clean` for a
family of its programs at every size.
-/

open GPUProof

namespace MojoProofTest.GPUProof.Toy

/-- A level of the toy machine: `0` (`⊥`) the thread, `⊤` the whole launch, and each `k` between
them the level of the launch's blocks of `span ws k` consecutive threads. -/
abbrev Lvl := WithTop Nat

/-- An instruction of the toy machine. -/
inductive Ins where
  /-- Read `len` bytes of buffer `b` from offset `off` through proxy `p`. -/
  | read (b : Nat) (off : Int) (len : Nat) (p : Bool)
  /-- Write the value `v` to `len` bytes of buffer `b` from offset `off` through proxy `p`. -/
  | write (b : Nat) (off : Int) (len : Nat) (v : UInt8) (p : Bool)
  /-- Add `v` to byte `off` of buffer `b`, through proxy `false`, with the result unused. -/
  | add (b : Nat) (off : Int) (v : UInt8)
  /-- Wait at the barrier of this thread's instance of level `ℓ` (`bar ⊤`, the whole launch's). -/
  | bar (ℓ : Lvl)
  /-- A proxy fence from proxy `p` to proxy `q`. -/
  | fence (p q : Bool)
  deriving DecidableEq

/-- A memory of the toy machine: the bytes of each buffer, if the buffer is allocated. -/
abbrev Memory := Nat → Option (List UInt8)

/-- A trace event of the toy machine: agents are threads (there are no jobs), buffers are numbers,
the one update operation is `()`, proxies are `Bool`, and objects are numbers. -/
abbrev Ev := Event (Agent Nat Empty) Nat Unit Bool Nat

/-- A state of the toy machine. -/
structure St where
  /-- The state of the toy machine with this launch, these statuses, memory and trace. -/
  mk ::
  /-- The number of threads of the launch. -/
  n : Nat
  /-- The widths of the launch's levels, from the thread up (`span`). -/
  ws : List Nat
  /-- Each thread's status, with the instructions it has left, and the level of the barrier it
  waits at. -/
  th : Nat → Status (List Ins) Lvl
  /-- The memory. -/
  mem : Memory
  /-- The events logged so far, oldest first. -/
  trace : List Ev

/-- Byte `l.2` of buffer `l.1` of memory `m`, if the buffer is allocated and has that byte. -/
def byte (m : Memory) (l : Nat × Int) : Option UInt8 :=
  (m l.1).bind fun bs => if 0 ≤ l.2 then bs[l.2.toNat]? else none

/-- The `len` bytes of buffer `b` from offset `off` are bytes of the buffer in memory `m`. -/
def inBounds (m : Memory) (b : Nat) (off : Int) (len : Nat) : Bool :=
  match m b with
  | some bs => decide (0 ≤ off) && decide (off + len ≤ bs.length)
  | none => false

/-- Memory `m` with each byte `x` of buffer `b` from offset `off` to `off + len` replaced by
`f x`. -/
def store (m : Memory) (b : Nat) (off : Int) (len : Nat) (f : UInt8 → UInt8) : Memory :=
  fun b' => if b' = b then (m b).map (List.mapIdx fun i x =>
    if off ≤ (i : Int) ∧ (i : Int) < off + len then f x else x) else m b'

/-- Instruction `i` may run on memory `m`: an access's bytes are in bounds. -/
def fits (m : Memory) : Ins → Bool
  | .read b off len _ | .write b off len _ _ => inBounds m b off len
  | .add b off _ => inBounds m b off 1
  | .bar _ | .fence _ _ => true

/-- The memory after instruction `i` on memory `m`: a write stores its value, an update adds its
operand; the other instructions leave `m`. -/
def effect (m : Memory) : Ins → Memory
  | .write b off len v _ => store m b off len fun _ => v
  | .add b off v => store m b off 1 (· + v)
  | _ => m

/-- The access of thread `t` to `len` bytes of buffer `b` from offset `off`, of kind `k`, through
proxy `p`. -/
def acc (t b : Nat) (off : Int) (len : Nat) (k : Kind Unit) (p : Bool) : Ev :=
  .access ⟨.thread t, b, off, len, k, p⟩

/-- What thread `t`'s instruction `i` logs: its access or its fence; a barrier wait logs
nothing. -/
def logs (t : Nat) : Ins → List Ev
  | .read b off len p => [acc t b off len .read p]
  | .write b off len _ p => [acc t b off len .write p]
  | .add b off _ => [acc t b off 1 (.rmw ()) false]
  | .bar _ => []
  | .fence p q => [.fence (.thread t) p q]

/-- State `s` with thread `t`'s status set to `st`. -/
def setTh (s : St) (t : Nat) (st : Status (List Ins) Lvl) : St :=
  { s with th := fun u => if u = t then st else s.th u }

/-- A thread's status after instruction `i` with the instructions `rest` after it: waiting at
level `ℓ` after the barrier `bar ℓ`, else running `rest`. -/
def after (i : Ins) (rest : List Ins) : Status (List Ins) Lvl :=
  match i with
  | .bar ℓ => .wait rest ℓ
  | _ => .run rest

/-- Thread `t` runs instruction `i` with the instructions `rest` after it: a fault when `i` does
not fit the memory; else its effect, its events, and `rest` left, waiting when `i` is a
barrier (`after`). -/
def exec (s : St) (t : Nat) (i : Ins) (rest : List Ins) : Except Unit (Option St) :=
  if fits s.mem i then
    .ok (some { setTh s t (after i rest) with
      mem := effect s.mem i, trace := s.trace ++ logs t i })
  else .error ()

/-- An agent's step: a running thread with no instruction left returns, a running thread with an
instruction runs it (`exec`), and a waiting or returned thread does not step. -/
def step (s : St) : Agent Nat Empty → Except Unit (Option St)
  | .thread t =>
    match s.th t with
    | .run [] => .ok (some (setTh s t .done))
    | .run (i :: rest) => exec s t i rest
    | _ => .ok none
  | .job j => nomatch j

/-- The number of threads in one instance of level `k` of a launch whose level widths are `ws`
(from the thread up): the product of the first `k` widths, `1` at the thread, and the product of
all of them at every level past the last width. -/
def span (ws : List Nat) (k : Nat) : Nat := (ws.take k).prod

/-- Thread `t`'s instance of level `ℓ` in a launch of level widths `ws`: the level, and an index,
`0` at `⊤` and `t / span ws k` at level `k`. -/
def groupOf (ws : List Nat) (ℓ : Lvl) (t : Nat) : Lvl × Nat :=
  (ℓ, if ℓ = ⊤ then 0 else t / span ws (ℓ.untopD 0))

/-- The members of instance `g` of a launch of `n` threads and level widths `ws`: the threads
below `n` whose instance at `g`'s level is `g`, in order. -/
def membersOf (n : Nat) (ws : List Nat) (g : Lvl × Nat) : List Nat :=
  (List.range n).filter fun u => decide (groupOf ws g.1 u = g)

/-- The object of the barrier of instance `g`: `0` at `⊤` (the launch's barrier), and at level
`k` the number `Nat.pair k i + 1` of the instance's index `i`, so distinct instances below `⊤`
have distinct objects. -/
def barObj (g : Lvl × Nat) : Nat :=
  if g.1 = ⊤ then 0 else Nat.pair (g.1.untopD 0) g.2 + 1

/-- Every member of instance `g` of the launch of `s` waits at the barrier of `g`'s level. -/
def allWait (s : St) (g : Lvl × Nat) : Bool :=
  (membersOf s.n s.ws g).all fun u => match s.th u with
    | .wait _ ℓ => decide (ℓ = g.1)
    | _ => false

/-- The rendezvous of the barrier of instance `g` of a launch of `n` threads and level widths
`ws`: the members of `g`, at object `barObj g`. -/
def barSync (n : Nat) (ws : List Nat) (g : Lvl × Nat) : Ev :=
  .sync (barObj g) ((membersOf n ws g).map .thread)

/-- The barrier of thread `t`'s instance `g` of level `ℓ` completes at `t` waiting at `ℓ` when
every member of `g` waits at `ℓ`: the members of `g` run again and the rendezvous of `g` is
logged; else there is no completion. -/
def complete (s : St) (t : Nat) : Except Unit (Option St) :=
  match s.th t with
  | .wait _ ℓ =>
    if allWait s (groupOf s.ws ℓ t) then
      .ok (some { s with
        th := fun u => if (membersOf s.n s.ws (groupOf s.ws ℓ t)).contains u then
            match s.th u with
            | .wait k _ => .run k
            | st => st
          else s.th u,
        trace := s.trace ++ [barSync s.n s.ws (groupOf s.ws ℓ t)] })
    else .ok none
  | _ => .ok none

/-- What an agent's next step would log. -/
def logged (s : St) : Agent Nat Empty → List Ev
  | .thread t =>
    match s.th t with
    | .run (i :: _) => logs t i
    | _ => []
  | .job _ => []

/-- What a completion at thread `t` would log. -/
def completes (s : St) (t : Nat) : List Ev :=
  match s.th t with
  | .wait _ ℓ =>
    if allWait s (groupOf s.ws ℓ t) then [barSync s.n s.ws (groupOf s.ws ℓ t)] else []
  | _ => []

/-- The slots instruction `i` reads: the buffer it names, and the bytes of a read or an update. -/
def slots : Ins → List ((Nat × Int) ⊕ Nat)
  | .read b off len _ => .inr b :: (List.range len).map fun k : Nat => .inl (b, off + (k : Int))
  | .write b _ _ _ _ => [.inr b]
  | .add b off _ => [.inr b, .inl (b, off)]
  | .bar _ | .fence _ _ => []

/-- The slots an agent's next step may read. -/
def readSet (s : St) : Agent Nat Empty → List ((Nat × Int) ⊕ Nat)
  | .thread t =>
    match s.th t with
    | .run (i :: _) => slots i
    | _ => []
  | .job _ => []

/-- Two states agree on what agent `a`'s next step reads: `a`'s status, and each slot of
`readSet s a` (a byte's value, a buffer's size). -/
def AgreeSt (s : St) (a : Agent Nat Empty) (s' : St) : Prop :=
  (match a with
    | .thread t => s.th t = s'.th t
    | .job _ => True) ∧
  ∀ x ∈ readSet s a, match x with
    | .inl l => byte s.mem l = byte s'.mem l
    | .inr b => (s.mem b).map List.length = (s'.mem b).map List.length

/-- Two states are the same up to the order of trace events: equal launches (threads and level
widths), statuses and memories, and traces that are permutations of each other. -/
def SameSt (s s' : St) : Prop :=
  s.n = s'.n ∧ s.ws = s'.ws ∧ s.th = s'.th ∧ s.mem = s'.mem ∧ s.trace.Perm s'.trace

/-- A step's effect: the agent's new status, and the instruction whose memory operation and events
it applies, if any. -/
abbrev Effect := Status (List Ins) Lvl × Option Ins

/-- State `s` with agent `a`'s step effect `d` applied. -/
def applyEff (s : St) : Agent Nat Empty → Effect → St
  | .thread t, (st, i) =>
    { setTh s t st with
      mem := (i.map (effect s.mem)).getD s.mem,
      trace := s.trace ++ (i.map (logs t)).getD [] }
  | .job _, _ => s

/-- The start of a launch of program `P` on `n` threads of level widths `ws` (none by default:
only the thread and the launch) over memory `m`: thread `t < n` runs `P t`, the other threads have
returned, and the trace is empty. -/
def launch (P : Nat → List Ins) (n : Nat) (m : Memory) (ws : List Nat := []) : St :=
  { n, ws, th := fun t => if t < n then .run (P t) else .done, mem := m, trace := [] }

/-- The toy machine: threads over a byte memory with reads, writes, updates, a barrier per level
instance and fences, and no jobs. A launch is a number of threads and the widths of its levels;
the level instances are `groupOf`'s. -/
def toy : Sig where
  Launch := Nat × List Nat
  Tid := Nat
  Job := Empty
  threads L := List.range L.1
  Level := Lvl
  Gid := Lvl × Nat
  group L ℓ t := groupOf L.2 ℓ t
  levelOf g := g.1
  members L g := membersOf L.1 L.2 g
  Space := Unit
  home _ := ⊤
  Loc := Nat × Int
  space _ := ()
  Byte := UInt8
  Buf := Nat
  place b i := (b, i)
  placeInj := some ⟨fun h => Prod.mk.inj h⟩
  Meta := Nat
  Bytes := Memory
  byteAt := byte
  metaAt m b := (m b).map List.length
  Op := Unit
  commutes _ := true
  combine _ old v := if old.length = v.length then some (List.zipWith (· + ·) old v) else none
  Proxy := Bool
  exempt a b :=
    match a.kind, b.kind with
    | .rmw _, .rmw _ => decide (a.buf = b.buf ∧ a.off = b.off ∧ a.len = b.len ∧ a.proxy = b.proxy)
    | _, _ => false
  Obj := Nat
  Prog := Nat → List Ins
  Val := Nat
  Mem := Memory
  memBytes m := m
  Choice := Unit
  FloatSite := Empty
  site _ _ := 0
  State := St
  Thread := List Ins
  Site := Nat
  Call := Lvl
  CollKind := Lvl
  kindOf c := c
  operandsOf _ := []
  siteOf k := some k.length
  level k := k
  orders _ := true
  Fault := Unit
  launchOf s := (s.n, s.ws)
  status s t := s.th t
  jobs _ := []
  landed _ _ := true
  bytes s := s.mem
  trace s := s.trace
  pending := logged
  firePending := completes
  reads := readSet
  resume k _ := k
  start P L _ m _ := .ok (launch P L.1 m L.2)
  advance := step
  fire := complete
  Same := SameSt
  Agree := AgreeSt
  Delta := Effect
  apply := applyEff
  Closed _ _ := True
  ArgsOk _ _ _ := True
  StartOk _ _ := True
  ValidLaunch L := 0 < L.1
  launchCells _ := []
  endLaunch _ s := s.mem

/-- One test machine (`toy`): the laws of its level instances hold at every launch, for every
number of threads and every list of level widths. -/
instance : Levels toy where
  mem_members {L g u} := by
    obtain ⟨n, ws⟩ := L
    obtain ⟨ℓ, i⟩ := g
    have key : ∀ u : Nat, u ∈ membersOf n ws (ℓ, i) ↔ u ∈ List.range n ∧ groupOf ws ℓ u = (ℓ, i) :=
      fun u => by rw [membersOf, List.mem_filter, decide_eq_true_eq]
    exact key u
  levelOf_group := rfl
  nest {L ℓ ℓ' t u} hle h := by
    obtain ⟨n, ws⟩ := L
    have key : ∀ (ℓ ℓ' : Lvl) (t u : Nat), ℓ ≤ ℓ' → groupOf ws ℓ t = groupOf ws ℓ u →
        groupOf ws ℓ' t = groupOf ws ℓ' u := by
      intro ℓ ℓ' t u hle h
      induction ℓ' using WithTop.recTopCoe with
      | top => simp [groupOf]
      | coe k' =>
        induction ℓ using WithTop.recTopCoe with
        | top => exact absurd hle (by simp)
        | coe k =>
          rw [WithTop.coe_le_coe] at hle
          obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hle
          simp only [groupOf, WithTop.coe_ne_top, ite_false, WithTop.untopD_coe, Prod.mk.injEq,
            true_and] at h ⊢
          have hs : span ws (k + d) = span ws k * ((ws.drop k).take d).prod := by
            simp [span, List.take_add, List.prod_append]
          rw [hs, ← Nat.div_div_eq_div_mul, ← Nat.div_div_eq_div_mul, h]
    exact key ℓ ℓ' t u hle h
  top {L t} _ := by
    obtain ⟨n, ws⟩ := L
    show (membersOf n ws (groupOf ws ⊤ t)).Perm (List.range n)
    rw [membersOf, List.filter_eq_self.2 fun u _ => by simp [groupOf]]
  bot {L t} ht := by
    obtain ⟨n, ws⟩ := L
    have key : ∀ t : Nat, t ∈ List.range n →
        membersOf n ws (groupOf ws ((0 : Nat) : Lvl) t) = [t] := by
      intro t ht
      have hg : ∀ u, groupOf ws ((0 : Nat) : Lvl) u = (((0 : Nat) : Lvl), u) := fun u => by
        simp [groupOf, show span ws 0 = 1 from rfl]
      simp only [membersOf, hg, Prod.mk.injEq, true_and]
      rw [List.filter_eq, List.nodup_range.count_of_mem ht, List.replicate_one]
    exact key t ht
  nodup {L g} := by
    obtain ⟨n, ws⟩ := L
    exact ⟨show (List.range n).Nodup from List.nodup_range,
      show (membersOf n ws g).Nodup from List.nodup_range.filter _⟩

/-- The state of a step result, if it is a step. -/
def okState : Except Unit (Option St) → Option St
  | .ok o => o
  | .error _ => none

/-- The toy schedule's next state from `s`: the first thread below `s.n` that steps, else the
first at which the barrier completes. -/
def sched (s : St) : Option St :=
  ((List.range s.n).findSome? fun t => okState (step s (.thread t))).or
    ((List.range s.n).findSome? fun t => okState (complete s t))

/-- A step result whose state is `s'` is the step to `s'`. -/
theorem okState_eq_some {e : Except Unit (Option St)} {s' : St} (h : okState e = some s') :
    e = .ok (some s') := by
  cases e with
  | error => cases h
  | ok o => cases o with
    | none => cases h
    | some x => cases h; rfl

/-- Every next state of the toy schedule is a `Step` of the toy machine, at every state. -/
theorem sched_step {s s' : St} (h : sched s = some s') : Step toy s s' := by
  unfold sched at h
  rcases ho : (List.range s.n).findSome? (fun t => okState (step s (.thread t))) with _ | x
  · rw [ho, Option.none_or] at h
    obtain ⟨t, -, ht⟩ := List.exists_of_findSome?_eq_some h
    exact Or.inr ⟨t, okState_eq_some ht⟩
  · rw [ho, Option.some_or] at h
    cases h
    obtain ⟨t, -, ht⟩ := List.exists_of_findSome?_eq_some ho
    exact Or.inl ⟨.thread t, okState_eq_some ht⟩

/-- `k` steps of the toy schedule from `s`, or fewer when it stops. -/
def runFor : Nat → St → St
  | 0, s => s
  | k + 1, s =>
    match sched s with
    | some s' => runFor k s'
    | none => s

/-- The toy schedule's states are reachable on the toy machine, for every number of steps and
start. -/
theorem runFor_reach (k : Nat) (s : St) : Reach toy s (runFor k s) := by
  induction k generalizing s with
  | zero => exact Relation.ReflTransGen.refl
  | succ k ih =>
    unfold runFor
    split
    · next s' h => exact Relation.ReflTransGen.head (sched_step h) (ih s')
    · exact Relation.ReflTransGen.refl

/-- One test machine (`toy`): every state reachable from the start of a launch of `n` threads of
level widths `ws` keeps that launch, and its trace is laminar for it (`GPUProof.Laminar`), for
every program, `n`, `ws` and memory: the machine logs accesses, fences, and rendezvous of the
members of one level instance. -/
theorem reach_laminar {P : Nat → List Ins} {n : Nat} {ws : List Nat} {m : Memory} {s : St}
    (h : Reach toy (launch P n m ws) s) : s.n = n ∧ s.ws = ws ∧ Laminar toy (n, ws) s.trace := by
  induction h with
  | refl => exact ⟨rfl, rfl, fun _ he => nomatch he⟩
  | @tail s₁ s₂ _ hst ih =>
    obtain ⟨hn, hw, hl⟩ := ih
    rcases hst with ⟨a, ha⟩ | ⟨t, ht⟩
    · rcases a with t | j
      · change step s₁ (.thread t) = .ok (some s₂) at ha
        cases hth : s₁.th t with
        | run k =>
          cases k with
          | nil =>
            simp only [step, hth, Except.ok.injEq, Option.some.injEq] at ha
            subst ha
            exact ⟨hn, hw, hl⟩
          | cons i rest =>
            simp only [step, hth, exec] at ha
            split at ha
            · simp only [Except.ok.injEq, Option.some.injEq] at ha
              subst ha
              refine ⟨hn, hw, fun e he => ?_⟩
              rcases List.mem_append.1 he with he | he
              · exact hl e he
              · have hlog : ∀ (i : Ins) (e : Ev), e ∈ logs t i →
                    (∃ a, e = .access a) ∨ ∃ w p q, e = .fence w p q := by
                  intro i e he
                  cases i with
                  | bar _ => simp [logs] at he
                  | fence p q => exact .inr ⟨_, p, q, List.mem_singleton.1 he⟩
                  | _ => exact .inl ⟨_, List.mem_singleton.1 he⟩
                rcases hlog i e he with h | h
                · exact .inl h
                · exact .inr (.inl h)
            · cases ha
        | wait k c => simp [step, hth] at ha
        | done => simp [step, hth] at ha
      · exact Empty.elim j
    · change complete s₁ t = .ok (some s₂) at ht
      cases hth : s₁.th t with
      | wait k ℓ =>
        simp only [complete, hth] at ht
        split at ht
        · simp only [Except.ok.injEq, Option.some.injEq] at ht
          subst ht
          refine ⟨hn, hw, fun e he => ?_⟩
          rcases List.mem_append.1 he with he | he
          · exact hl e he
          · have he' := List.mem_singleton.1 he
            subst he'
            refine .inr (.inr ⟨_, _, groupOf s₁.ws ℓ t, rfl, fun c => ?_⟩)
            show c ∈ (membersOf s₁.n s₁.ws (groupOf s₁.ws ℓ t)).map Agent.thread ↔
              ∃ u ∈ membersOf n ws (groupOf s₁.ws ℓ t), c = .thread u
            rw [hn, hw]
            constructor
            · intro hc
              obtain ⟨u, hu, rfl⟩ := List.mem_map.1 hc
              exact ⟨u, hu, rfl⟩
            · rintro ⟨u, hu, rfl⟩
              exact List.mem_map.2 ⟨u, hu, rfl⟩
        · cases ht
      | run k => simp [complete, hth] at ht
      | done => simp [complete, hth] at ht

/-- Buffer `0` of `n` zero bytes; no other buffer is allocated. -/
def zeros (n : Nat) : Memory :=
  fun b => if b = 0 then some (List.replicate n 0) else none

/-- Every thread of `s` below `s.n` has returned. -/
def allDone (s : St) : Bool :=
  (List.range s.n).all fun t => decide (s.th t = .done)

/-- The toy schedule enables no step at `s` (`sched s = none`): a run that reaches `s` has
stopped. -/
def stopped (s : St) : Bool := (sched s).isNone

/-- The toy schedule on program `P` at `n` threads over `zeros n`, run for at most `10 * n + 10`
steps (`runFor`): the state where the schedule stops, if it stops within that many steps, and
otherwise the state after the last of them, with a step still enabled. `final` does not tell the
two apart; the tests that need a stopped run check `allDone` and `stopped`. -/
def final (P : Nat → List Ins) (n : Nat) : St :=
  runFor (10 * n + 10) (launch P n (zeros n))

/-- Thread `t` of `n` writes `t` to byte `t` of buffer `0`, waits at the launch's barrier when
`sync`, and reads byte `t + 1` (mod `n`), its neighbor's. -/
def ring (sync : Bool) (n t : Nat) : List Ins :=
  [.write 0 t 1 (UInt8.ofNat t) false] ++ (if sync then [.bar ⊤] else []) ++
    [.read 0 ((t + 1) % n : Nat) 1 false]

-- with the barrier: the run ends, writes the bytes, and its trace passes `racy` and `kept`
#guard [3, 7].all fun n =>
  let z := final (ring true n) n
  allDone z && stopped z && !racy toy z.trace && kept toy z.trace &&
    z.mem 0 == some ((List.range n).map UInt8.ofNat) && z.trace.length == 2 * n + 1
-- the mutant without the barrier: `racy` refuses it
#guard [3, 7].all fun n =>
  let z := final (ring false n) n
  allDone z && stopped z && racy toy z.trace

/-- One test machine (`toy`): at 8 threads the ring's run with the barrier is race free and the
mutant's without it is racy, checked by the kernel, which runs the schedule and `racy` itself
(`decide +kernel`). -/
theorem ring_racy_kernel :
    racy toy (final (ring true 8) 8).trace = false ∧
      racy toy (final (ring false 8) 8).trace = true := by
  decide +kernel

/-- Thread `t` writes `1` to byte `t` of buffer `0` through proxy `false`, fences from proxy
`false` to proxy `true` when `fenced`, and reads the byte back through proxy `true`. -/
def crossProxy (fenced : Bool) (t : Nat) : List Ins :=
  [.write 0 t 1 1 false] ++ (if fenced then [.fence false true] else []) ++ [.read 0 t 1 true]

-- one agent, two proxies: race free with the fence, racy without it
#guard [3, 7].all fun n =>
  let z := final (crossProxy true) n
  allDone z && stopped z && !racy toy z.trace
#guard [3, 7].all fun n => racy toy (final (crossProxy false) n).trace
-- the fence the wrong way round does not order the pair
#guard [3, 7].all fun n =>
  racy toy (final (fun t => [.write 0 t 1 1 false, .fence true false, .read 0 t 1 true]) n).trace

-- every thread adds `1` to byte `0`: the machine exempts the updates, and the byte ends at `n`
#guard [3, 7].all fun n =>
  let z := final (fun _ => [.add 0 0 1]) n
  allDone z && stopped z && !racy toy z.trace &&
    z.mem 0 == some (UInt8.ofNat n :: List.replicate (n - 1) 0)
-- `final`'s fuel bounds the run: one thread's 21 writes outlast the 20 steps, and `stopped` says so
#guard !stopped (final (fun _ => List.replicate 21 (.write 0 0 1 0 false)) 1) &&
  stopped (runFor 30 (launch (fun _ => List.replicate 21 (.write 0 0 1 0 false)) 1 (zeros 1)))
-- a write past the end of buffer `0` faults
#guard [3, 7].all fun n =>
  match step (launch (fun t => [.write 0 (n - 1 + t : Nat) 2 0 false]) n (zeros n)) (.thread 0) with
  | .error _ => true
  | .ok _ => false

end MojoProofTest.GPUProof.Toy
