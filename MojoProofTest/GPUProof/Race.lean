import MojoProofTest.GPUProof.Toy

/-!
# The race check on traces

Short traces of the toy machine (MojoProofTest/GPUProof/Toy.lean), each built at a size `n` and
checked at `n = 3` and `n = 7` by evaluation (`#guard`). For every event form there is a trace
that `racy` passes and one it refuses, and every rule of the check has a mutant: a trace that
differs from a passing one only where the rule looks, which the check refuses.

* An access (`acc`): two writes sharing a byte race, and the mutant moved off by one byte does not
  (`Access.conflict`'s shared byte); two reads do not race, and the mutant with one write does
  (one of them writes); two unused-result updates of one interval are exempt, and the mutants
  with a used result, another interval or another proxy race (`Sig.exempt`); one thread's two
  writes are ordered, and the mutant by two threads races (program order).
* Placement: writes to two buffers do not race on `toy`, which places buffers apart (`PlaceInj`),
  and the mutant machine `aliased`, which places every buffer at the same bytes and so has no
  `PlaceInj` law, refuses them (`aliased_Racy`, through `GPUProof.racy_iff`).
* A rendezvous (`sync`): it orders its members, and the mutant without the reader among its
  members races.
* A release and an acquire (`rel`, `acq`): an acquire of the released phase orders the pair; the
  mutants with another phase, another object, the acquire before the release, a release alone or
  an acquire alone race. A chain of `n - 1` hand-overs orders the ends (`HB`'s transitivity),
  and the mutant with one link broken races.
* A fence (`fence`): a write through one proxy and a read through the other are ordered by a
  fence from the first proxy to the second between them, by the same thread or by another on the
  path; the mutants without the fence, with the fence reversed, before the write or after the
  read, race.
* `hb` and `ordered`, the checks the race check calls, on the chain and on the fenced pair.
* `kept`: a write that shares a byte with a frozen read breaks it, before or after the read,
  ordered or not, by an update or by the same thread; a read, or a write of the next byte,
  does not.
* `GPUProof.kept_iff` both ways: `Kept` from `kept` on the write of the next byte, at 3 and 7
  bytes (`kept_next_Kept`); `kept` from a proof of `Kept` on it, at every size (`kept_next`);
  and not `Kept` on the write of the last byte, which `kept` refuses (`not_Kept_last`).
-/

open GPUProof MojoProofTest.GPUProof.Toy

namespace MojoProofTest.GPUProof.Race

/-- Thread `t`'s write of `len` bytes of buffer `0` from offset `off`, through proxy `p`. -/
def w (t : Nat) (off : Int) (len : Nat) (p : Bool := false) : Ev := acc t 0 off len .write p

/-- Thread `t`'s read of `len` bytes of buffer `0` from offset `off`, through proxy `p`. -/
def r (t : Nat) (off : Int) (len : Nat) (p : Bool := false) : Ev := acc t 0 off len .read p

/-- Thread `t`'s release of phase `ph` of object `o`. -/
def rel (t o ph : Nat) : Ev := .rel (.thread t) o ph

/-- Thread `t`'s acquire of phase `ph` of object `o`. -/
def acq (t o ph : Nat) : Ev := .acq (.thread t) o ph

/-- Thread `t`'s fence from proxy `p` to proxy `q`. -/
def fen (t : Nat) (p q : Bool) : Ev := .fence (.thread t) p q

/-- The rendezvous of the threads `ts` at object `0`. -/
def syncOf (ts : List Nat) : Ev := .sync 0 (ts.map .thread)

/-- `racy` passes the trace `good n` and refuses the trace `bad n`, at `n = 3` and `n = 7`. -/
def passRefuse (good bad : Nat → List Ev) : Bool :=
  [3, 7].all fun n => !racy toy (good n) && racy toy (bad n)

-- an access: a shared byte (the writes of `[0, n)` and `[n - 1, 2n - 1)` share byte `n - 1`)
#guard passRefuse (fun n => [w 0 0 n, w 1 n n]) (fun n => [w 0 0 n, w 1 (n - 1 : Nat) n])
-- one of them writes
#guard passRefuse (fun n => [r 0 0 n, r 1 0 n]) (fun n => [r 0 0 n, w 1 0 n])
#guard passRefuse (fun n => [r 0 0 n, r 1 0 n]) (fun n => [w 0 0 n, r 1 0 n])
-- the exemption: two unused-result updates of one interval through one proxy
#guard passRefuse (fun n => [acc 0 0 0 n (.rmw ()) false, acc 1 0 0 n (.rmw ()) false])
  (fun n => [acc 0 0 0 n (.rmw ()) false, acc 1 0 0 n (.rmwRet ()) false])
#guard passRefuse (fun n => [acc 0 0 0 n (.rmw ()) false, acc 1 0 0 n (.rmw ()) false])
  (fun n => [acc 0 0 0 n (.rmw ()) false, acc 1 0 1 n (.rmw ()) false])
#guard passRefuse (fun n => [acc 0 0 0 n (.rmw ()) false, acc 1 0 0 n (.rmw ()) false])
  (fun n => [acc 0 0 0 n (.rmw ()) false, acc 1 0 0 n (.rmw ()) true])
-- program order: one thread's accesses through one proxy, then the same by two threads
#guard passRefuse (fun n => [w n 0 n, r 2 n n, w n 0 n]) (fun n => [w n 0 n, r 2 n n, w 1 0 n])

/-- The toy machine with every buffer placed at buffer `0`'s bytes: its buffers alias, so it has
no `PlaceInj` law, and its race check compares bytes (`Sig.placeInj` is `none`). -/
def aliased : Sig := { toy with place := fun _ i => (0, i), placeInj := none }

/-- Thread `0`'s write of bytes `0` to `n - 1` of buffer `0`, and thread `1`'s of buffer `1`. -/
def twoBufs (n : Nat) : List Ev := [acc 0 0 0 n .write false, acc 1 1 0 n .write false]

-- placement: `toy` places two buffers apart, so their writes do not race; `aliased` places them
-- at the same bytes, so they race, though their buffers differ (`Access.meets` is false)
#guard [3, 7].all fun n => !racy toy (twoBufs n) && racy aliased (twoBufs n) &&
  !Access.meets aliased ⟨.thread (0 : Nat), (0 : Nat), 0, n, .write, false⟩
    ⟨.thread (1 : Nat), (1 : Nat), 0, n, .write, false⟩

/-- One test machine without the `PlaceInj` law (`aliased`) and one with it (`toy`), at two sizes:
the writes of bytes `0` to `n - 1` of buffers `0` and `1` (`twoBufs`), at `n = 3` and `n = 7`,
race on `aliased`, whose buffers alias, and not on `toy`. `racy` decides both
(`GPUProof.racy_iff`). -/
theorem aliased_Racy : Racy aliased (twoBufs 3) ∧ Racy aliased (twoBufs 7) ∧
    ¬ Racy toy (twoBufs 3) ∧ ¬ Racy toy (twoBufs 7) :=
  ⟨(racy_iff aliased).1 (by decide +kernel), (racy_iff aliased).1 (by decide +kernel),
    fun h => absurd ((racy_iff toy).2 h) (by decide +kernel),
    fun h => absurd ((racy_iff toy).2 h) (by decide +kernel)⟩

-- a rendezvous orders its members, and only them
#guard passRefuse (fun n => [w 0 0 n, syncOf (List.range n), r (n - 1) 0 n])
  (fun n => [w 0 0 n, syncOf (List.range (n - 1)), r (n - 1) 0 n])

-- a release and an acquire of one phase of one object
#guard passRefuse (fun n => [w 0 0 n, rel 0 n n, acq 1 n n, r 1 0 n])
  (fun n => [w 0 0 n, rel 0 n n, acq 1 n (n + 1), r 1 0 n])
#guard passRefuse (fun n => [w 0 0 n, rel 0 n n, acq 1 n n, r 1 0 n])
  (fun n => [w 0 0 n, rel 0 n n, acq 1 (n + 1) n, r 1 0 n])
#guard passRefuse (fun n => [w 0 0 n, rel 0 n n, acq 1 n n, r 1 0 n])
  (fun n => [w 0 0 n, acq 1 n n, rel 0 n n, r 1 0 n])
#guard passRefuse (fun n => [w 0 0 n, rel 0 n n, acq 1 n n, r 1 0 n])
  (fun n => [w 0 0 n, rel 0 n n, r 1 0 n])
#guard passRefuse (fun n => [w 0 0 n, rel 0 n n, acq 1 n n, r 1 0 n])
  (fun n => [w 0 0 n, acq 1 n n, r 1 0 n])

/-- Thread `0` writes `[0, n)`, hands it over through phases `0` to `n - 2` of object `1` to
threads `1` to `n - 1` in turn (thread `k` releases phase `k`, thread `k + 1` acquires it), and
thread `n - 1` reads it; when `broken`, the acquire of phase `n / 2` acquires phase `n` instead. -/
def chain (broken : Bool) (n : Nat) : List Ev :=
  [w 0 0 n] ++ (List.range (n - 1)).flatMap (fun k =>
    [rel k 1 k, acq (k + 1) 1 (if broken && k = n / 2 then n else k)]) ++ [r (n - 1) 0 n]

-- transitivity: a chain of `n - 1` hand-overs orders the ends, one broken link does not
#guard passRefuse (chain false) (chain true)
#guard [3, 7].all fun n => (chain false n).length == 2 * n

-- a fence from the write's proxy to the read's, between them on the path
#guard passRefuse (fun n => [w 0 0 n false, fen 0 false true, r 0 0 n true])
  (fun n => [w 0 0 n false, r 0 0 n true])
#guard passRefuse (fun n => [w 0 0 n false, fen 0 false true, r 0 0 n true])
  (fun n => [w 0 0 n false, fen 0 true false, r 0 0 n true])
#guard passRefuse (fun n => [w 0 0 n false, fen 0 false true, r 0 0 n true])
  (fun n => [fen 0 false true, w 0 0 n false, r 0 0 n true])
#guard passRefuse (fun n => [w 0 0 n false, fen 0 false true, r 0 0 n true])
  (fun n => [w 0 0 n false, r 0 0 n true, fen 0 false true])
-- a fence by another thread on the path: thread `n - 1` fences after the rendezvous
#guard passRefuse
  (fun n => [w 0 0 n false, syncOf (List.range n), fen (n - 1) false true, r (n - 1) 0 n true])
  (fun n => [w 0 0 n false, syncOf (List.range n), r (n - 1) 0 n true])
-- the fence does not order the other direction
#guard passRefuse (fun n => [w 0 0 n true, fen 0 true false, r 0 0 n false])
  (fun n => [w 0 0 n true, fen 0 false true, r 0 0 n false])

-- `hb` on the chain: it reaches from the write to the read, not back, and not across the break
#guard [3, 7].all fun n =>
  hb toy (chain false n) 0 (2 * n - 1) && !hb toy (chain false n) (2 * n - 1) 0 &&
    !hb toy (chain true n) 0 (2 * n - 1) && !hb toy (chain false n) 0 0
-- `ordered` through the fence, only from its first proxy to its second, and only on the path
#guard [3, 7].all fun n =>
  let tr := [w 0 0 n false, fen 0 false true, r 0 0 n true]
  ordered toy tr false true 0 2 && !ordered toy tr true false 0 2 &&
    !ordered toy [w 0 0 n false, fen 1 false true, r 1 0 n true] false true 0 2

/-- `kept` keeps the frozen reads of the trace `good n` and refuses the trace `bad n`, at `n = 3`
and `n = 7`. -/
def keepRefuse (good bad : Nat → List Ev) : Bool :=
  [3, 7].all fun n => kept toy (good n) && !kept toy (bad n)

-- a write of the next byte keeps the frozen read; one of its last byte breaks it
#guard keepRefuse (fun n => [acc 0 0 0 n .frozen false, w 1 n 1])
  (fun n => [acc 0 0 0 n .frozen false, w 1 (n - 1 : Nat) 1])
-- a read keeps it, an update breaks it
#guard keepRefuse (fun n => [acc 0 0 0 n .frozen false, r 1 0 n])
  (fun n => [acc 0 0 0 n .frozen false, acc 1 0 0 n (.rmw ()) false])
-- a write before the frozen read breaks it, even ordered before it, even by the same thread
#guard keepRefuse (fun n => [r 1 0 n, syncOf [0, 1], acc 0 0 0 n .frozen false])
  (fun n => [w 1 0 n, syncOf [0, 1], acc 0 0 0 n .frozen false])
#guard keepRefuse (fun n => [acc 0 0 0 n .frozen false, w 0 n n])
  (fun n => [acc 0 0 0 n .frozen false, w 0 0 n])
-- the race check passes the ordered write that breaks the frozen read
#guard [3, 7].all fun n => !racy toy [w 1 0 n, syncOf [0, 1], acc 0 0 0 n .frozen false]

/-- One test machine (`toy`): `GPUProof.kept_iff` from left to right, at 3 and 7 bytes. `kept`
keeps a frozen read of bytes `0` to `n - 1` followed by another thread's write of byte `n`, so
`Kept` holds of the trace. -/
theorem kept_next_Kept : Kept toy [acc 0 0 0 3 .frozen false, w 1 3 1] ∧
    Kept toy [acc 0 0 0 7 .frozen false, w 1 7 1] :=
  ⟨(kept_iff toy).1 (by decide +kernel), (kept_iff toy).1 (by decide +kernel)⟩

/-- One test machine (`toy`): `GPUProof.kept_iff` from right to left, at every size `n`. A frozen
read of bytes `0` to `n - 1` and another thread's write of byte `n` satisfy `Kept`, by hand, so
`kept` keeps the trace. -/
theorem kept_next (n : Nat) : kept toy [acc 0 0 0 n .frozen false, w 1 n 1] = true := by
  refine (kept_iff toy).2 fun x a hx ha hw hf l hl hlx => ?_
  rcases List.mem_cons.1 hx with hx | hx
  · injection hx with hx
    subst hx
    simp [Kind.writes] at hw
  injection List.mem_singleton.1 hx with hx
  subst hx
  rcases List.mem_cons.1 ha with ha | ha
  · injection ha with ha
    subst ha
    simp only [Access.locs, List.mem_map, List.mem_range] at hl hlx
    obtain ⟨i, hi, rfl⟩ := hl
    obtain ⟨j, hj, hji⟩ := hlx
    simp [toy] at hji
    omega
  · injection List.mem_singleton.1 ha with ha
    subst ha
    simp at hf

/-- One test machine (`toy`): `GPUProof.kept_iff` from right to left, by contraposition, at 3
and 7 bytes. `kept` refuses a frozen read of bytes `0` to `n - 1` followed by another thread's
write of byte `n - 1`, so `Kept` does not hold of the trace. -/
theorem not_Kept_last : ¬ Kept toy [acc 0 0 0 3 .frozen false, w 1 (3 - 1 : Nat) 1] ∧
    ¬ Kept toy [acc 0 0 0 7 .frozen false, w 1 (7 - 1 : Nat) 1] :=
  ⟨fun h => absurd ((kept_iff toy).2 h) (by decide +kernel),
    fun h => absurd ((kept_iff toy).2 h) (by decide +kernel)⟩

end MojoProofTest.GPUProof.Race
