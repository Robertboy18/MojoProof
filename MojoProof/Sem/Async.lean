import Mathlib.Data.List.Induction

/-!
# Asynchronous copies and their groups (docs/proofs/async-copy.md)

A thread's `cp.async` copies from global to shared memory, its group commits and its group
waits (`wait_group n`; PTX ISA 9.5, sections 9.7.10.28.3.1-3), as a per-thread state. A copy
is pending from its issue; a commit closes the copies issued since the previous commit into a
group (an empty group when there are none); `wait_group n` waits until at most the `n` most
recent groups are pending, so the older groups' copies land, oldest first. Copies not yet
committed are not waited for.

Definitions:
* `AsyncCopy`: one copy, `cp.async.<ca|cg>.shared.global [dst], [src], size, srcSize`;
  `AsyncCopy.land gm sm c`: the shared memory `sm` after `c` lands, reading the global memory `gm`.
* `AsyncOp`: a copy, a commit or a wait; `Async`: the uncommitted copies, the pending groups
  (oldest first) and the landed copies (in landing order); `Async.step`, `Async.run`.
* `Async.committed ops`: the copies of `ops` issued before its last commit, in order;
  `Async.uncommitted ops`: those issued after it.

Proved, for every sequence of operations from the empty state: `Async.wait_length` (after
`wait_group n` at most `n` groups are pending); `Async.run_init` (the landed copies followed by
the pending groups are the committed copies, the uncommitted ones are not in a group);
`Async.wait_run`; `Async.visible` (after `wait_group 0` every committed copy has landed, in order,
and no group is pending); `Async.visible_bytes` (after `wait_group 0` the bytes of every committed
copy are in shared memory, when the committed copies' destinations are pairwise disjoint).
That no other access touches a destination or a source while a copy is pending (race freedom) is
the caller's premise: the model reads the global memory `gm` when a copy lands, and no other
thread writes the shared memory.
-/

namespace MojoProof.Sem

/-- One `cp.async.<ca|cg>.shared.global [dst], [src], size, srcSize` (PTX ISA 9.5, section
9.7.10.28.3.1): `size` bytes to the shared address `dst`, of which the first `srcSize` come from
the global address `src` and the rest are zeros; without the `srcSize` operand, `srcSize = size`.
-/
structure AsyncCopy where
  /-- Builds a copy from its addresses and sizes. -/
  mk ::
  /-- The shared destination address. -/
  dst : Nat
  /-- The global source address. -/
  src : Nat
  /-- The number of bytes written (the ISA's `cp-size`). -/
  size : Nat
  /-- The number of bytes read (the ISA's `src-size`). -/
  srcSize : Nat
  deriving DecidableEq, Repr

/-- The shared memory `sm` after copy `c` lands, reading the global memory `gm`: byte
`c.dst + o` for `o < c.size` is `gm (c.src + o)` when `o < c.srcSize` and `0` otherwise; every
other byte is `sm`'s. -/
def AsyncCopy.land (gm sm : Nat → UInt8) (c : AsyncCopy) : Nat → UInt8 := fun x =>
  if c.dst ≤ x ∧ x < c.dst + c.size then
    if x - c.dst < c.srcSize then gm (c.src + (x - c.dst)) else 0
  else sm x

/-- The destinations of two copies do not overlap. -/
def AsyncCopy.Disjoint (x y : AsyncCopy) : Prop :=
  x.dst + x.size ≤ y.dst ∨ y.dst + y.size ≤ x.dst

/-- One of a thread's operations on its asynchronous copies. -/
inductive AsyncOp
  /-- `cp.async`: the copy `c` is issued. -/
  | copy (c : AsyncCopy)
  /-- `cp.async.commit_group` (PTX ISA 9.5, section 9.7.10.28.3.2). -/
  | commit
  /-- `cp.async.wait_group n` (PTX ISA 9.5, section 9.7.10.28.3.3). -/
  | wait (n : Nat)
  deriving DecidableEq, Repr

/-- The copy an operation issues, if it is one. -/
def AsyncOp.copy? : AsyncOp → Option AsyncCopy
  | .copy c => some c
  | _ => none

/-- Whether an operation is a commit. -/
def AsyncOp.isCommit : AsyncOp → Bool
  | .commit => true
  | _ => false

/-- A thread's asynchronous copies: those issued since the last commit, the committed groups
still pending (oldest first) and the copies that have landed (in landing order). -/
structure Async where
  /-- Builds the state from its three lists. -/
  mk ::
  /-- The copies issued since the last commit. -/
  pending : List AsyncCopy
  /-- The committed groups not yet complete, oldest first. -/
  groups : List (List AsyncCopy)
  /-- The copies that have landed, in order. -/
  landed : List AsyncCopy
  deriving DecidableEq, Repr

namespace Async

/-- The copies of `ops` issued before its last commit, in order (none without a commit). -/
def committed (ops : List AsyncOp) : List AsyncCopy :=
  (ops.reverse.dropWhile (!·.isCommit)).reverse.filterMap AsyncOp.copy?

/-- The copies of `ops` issued after its last commit, in order (all of them without a commit).
-/
def uncommitted (ops : List AsyncOp) : List AsyncCopy :=
  (ops.reverse.takeWhile (!·.isCommit)).reverse.filterMap AsyncOp.copy?

/-- The state of a thread that has issued no copy. -/
def init : Async := ⟨[], [], []⟩

/-- One operation: a copy joins the uncommitted copies; a commit closes them into the newest
group (empty if there are none); `wait n` lands the oldest groups, in order, until at most `n`
remain. -/
def step (s : Async) : AsyncOp → Async
  | .copy c => { s with pending := s.pending ++ [c] }
  | .commit => { s with pending := [], groups := s.groups ++ [s.pending] }
  | .wait n => { s with groups := s.groups.drop (s.groups.length - n),
                        landed := s.landed ++ (s.groups.take (s.groups.length - n)).flatten }

/-- The operations `ops` in order from `s`. -/
def run (s : Async) (ops : List AsyncOp) : Async :=
  ops.foldl step s

/-- The shared memory after the landed copies of `s`, in order, from `sm`, reading the global
memory `gm`. -/
def smem (gm sm : Nat → UInt8) (s : Async) : Nat → UInt8 :=
  s.landed.foldl (AsyncCopy.land gm) sm

/-- **`wait_group n` leaves at most `n` groups pending**, from every state and for every `n`. -/
theorem wait_length (s : Async) (n : Nat) : (s.step (.wait n)).groups.length ≤ n := by
  simp only [step, List.length_drop]
  omega

private theorem committed_append (ops : List AsyncOp) :
    committed ops ++ uncommitted ops = ops.filterMap AsyncOp.copy? := by
  rw [committed, uncommitted, ← List.filterMap_append, ← List.reverse_append,
    List.takeWhile_append_dropWhile, List.reverse_reverse]

/-- **The landed copies and the groups are the committed copies**, for every sequence of
operations `ops` from the empty state: the landed copies followed by the pending groups' copies
are `committed ops`, in order, and the copies not in a group are `uncommitted ops`. -/
theorem run_init (ops : List AsyncOp) :
    (init.run ops).landed ++ (init.run ops).groups.flatten = committed ops ∧
      (init.run ops).pending = uncommitted ops := by
  induction ops using List.reverseRecOn with
  | nil => exact ⟨rfl, rfl⟩
  | append_singleton ops x ih =>
    have hr : init.run (ops ++ [x]) = (init.run ops).step x := List.foldl_append ..
    rw [hr]
    obtain ⟨h1, h2⟩ := ih
    cases x with
    | copy c =>
      have hc : committed (ops ++ [.copy c]) = committed ops := by
        simp [committed, AsyncOp.isCommit]
      have hu : uncommitted (ops ++ [.copy c]) = uncommitted ops ++ [c] := by
        simp [uncommitted, AsyncOp.isCommit, AsyncOp.copy?]
      rw [hc, hu]
      exact ⟨h1, congrArg (· ++ [c]) h2⟩
    | commit =>
      have hc : committed (ops ++ [.commit]) = ops.filterMap AsyncOp.copy? := by
        simp [committed, AsyncOp.isCommit, AsyncOp.copy?]
      have hu : uncommitted (ops ++ [.commit]) = [] := by
        simp [uncommitted, AsyncOp.isCommit]
      rw [hc, hu]
      refine ⟨?_, rfl⟩
      rw [← committed_append, ← h1, ← h2]
      simp [step]
    | wait n =>
      have hc : committed (ops ++ [.wait n]) = committed ops := by
        simp [committed, AsyncOp.isCommit]
      have hu : uncommitted (ops ++ [.wait n]) = uncommitted ops := by
        simp [uncommitted, AsyncOp.isCommit, AsyncOp.copy?]
      rw [hc, hu]
      refine ⟨?_, h2⟩
      rw [← h1]
      simp only [step, List.append_assoc, ← List.flatten_append, List.take_append_drop]

/-- **After `wait_group n`**, for every sequence of operations `ops` from the empty state and
every `n`: at most `n` groups are pending, and the landed copies followed by the pending groups'
copies are `committed ops`, in order. -/
theorem wait_run (ops : List AsyncOp) (n : Nat) :
    (init.run (ops ++ [.wait n])).groups.length ≤ n ∧
      (init.run (ops ++ [.wait n])).landed ++ (init.run (ops ++ [.wait n])).groups.flatten =
        committed ops := by
  have hr : init.run (ops ++ [.wait n]) = (init.run ops).step (.wait n) := List.foldl_append ..
  refine ⟨hr ▸ wait_length _ n, ?_⟩
  rw [hr, ← (run_init ops).1]
  simp only [step, List.append_assoc, ← List.flatten_append, List.take_append_drop]

/-- **Visibility after `wait_group 0`**, for every sequence of operations `ops` from the empty
state: no group is pending, the landed copies are exactly `committed ops`, the copies issued
before `ops`' last commit, in order, and the copies issued after it are still uncommitted. -/
theorem visible (ops : List AsyncOp) :
    (init.run (ops ++ [.wait 0])).groups = [] ∧
      (init.run (ops ++ [.wait 0])).landed = committed ops ∧
      (init.run (ops ++ [.wait 0])).pending = uncommitted ops := by
  obtain ⟨h0, h1⟩ := wait_run ops 0
  have hg := List.eq_nil_of_length_eq_zero (Nat.le_zero.1 h0)
  have hp : (init.run (ops ++ [.wait 0])).pending = (init.run ops).pending := by
    rw [show init.run (ops ++ [.wait 0]) = (init.run ops).step (.wait 0) from
      List.foldl_append ..]
    rfl
  rw [hg, List.flatten_nil, List.append_nil] at h1
  exact ⟨hg, h1, hp.trans (run_init ops).2⟩

private theorem foldl_land_out (gm : Nat → UInt8) (x : Nat) :
    ∀ (cs : List AsyncCopy) (sm : Nat → UInt8), (∀ c ∈ cs, ¬(c.dst ≤ x ∧ x < c.dst + c.size)) →
      cs.foldl (AsyncCopy.land gm) sm x = sm x
  | [], _, _ => rfl
  | c :: cs, sm, h => by
    rw [List.foldl_cons, foldl_land_out gm x cs _ fun d hd => h d (List.mem_cons_of_mem _ hd)]
    simp [AsyncCopy.land, h c List.mem_cons_self]

private theorem foldl_land_mem (gm : Nat → UInt8) {c : AsyncCopy} {o : Nat} (ho : o < c.size) :
    ∀ (cs : List AsyncCopy) (sm : Nat → UInt8), cs.Pairwise AsyncCopy.Disjoint → c ∈ cs →
      cs.foldl (AsyncCopy.land gm) sm (c.dst + o) =
        if o < c.srcSize then gm (c.src + o) else 0
  | d :: cs, sm, hp, hc => by
    rw [List.pairwise_cons] at hp
    rw [List.foldl_cons]
    rcases List.mem_cons.1 hc with rfl | hc
    · rw [foldl_land_out gm _ cs _ fun e he hx => by
        rcases hp.1 e he with h | h <;> omega]
      simp [AsyncCopy.land, ho]
    · exact foldl_land_mem gm ho cs _ hp.2 hc

/-- **The copied bytes are visible after `wait_group 0`**, for every sequence of operations
`ops` from the empty state, global memory `gm` and initial shared memory `sm`: if the destinations
of `committed ops` are pairwise disjoint, then for every committed copy `c` and offset
`o < c.size`, the shared memory after `ops` and `wait_group 0` holds at `c.dst + o` the global
byte `gm (c.src + o)` when `o < c.srcSize`, and `0` otherwise. That nothing else writes the
destinations or the sources while the copies are pending is the caller's premise, not modelled. -/
theorem visible_bytes (ops : List AsyncOp) (gm sm : Nat → UInt8)
    (hd : (committed ops).Pairwise AsyncCopy.Disjoint) {c : AsyncCopy} (hc : c ∈ committed ops)
    {o : Nat} (ho : o < c.size) :
    (init.run (ops ++ [.wait 0])).smem gm sm (c.dst + o) =
      if o < c.srcSize then gm (c.src + o) else 0 := by
  rw [smem, (visible ops).2.1]
  exact foldl_land_mem gm ho _ sm hd hc

end Async

end MojoProof.Sem
