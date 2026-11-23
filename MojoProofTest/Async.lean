import MojoProof.Sem.Async

/-!
# Asynchronous copies: one sequence of copies, commits and waits

Tests of MojoProof/Sem/Async.lean on the operations `ops`: copy `c0` (16 bytes from global
address 0 to shared address 0), commit, copy `c1` (16 bytes from global 64 to shared 16, of which
4 are read: `src-size` 4), commit, copy `c2` (8 bytes from global 128 to shared 32), and no commit
after it.
* `split`: `committed ops` is `[c0, c1]` and `uncommitted ops` is `[c2]`.
* `wait1`: after `wait_group 1`, `c0` has landed, the group of `c1` is pending and `c2` is
  uncommitted, by evaluation; `wait1_run`: the instance of `wait_run` there.
* `wait0`: the instance of `visible`: after `wait_group 0`, `c0` and `c1` have landed, in order,
  and `c2` is still uncommitted.
* `bytes`: the instance of `visible_bytes`, with global byte `x` equal to `x % 256` (`gm`) and a
  shared memory of `0xff` bytes: byte 2 of `c1`'s destination is global byte 66, and byte 5 is
  0, past `src-size`.
* The twin `bytes_twin`: `c2`, issued after the last commit, has not landed after
  `wait_group 0`; its destination still holds `0xff`.
* The twin `overlap`: of two committed copies to the same 4 bytes, from global addresses 0 and
  100, the first is not visible after `wait_group 0`, as the second overwrote it; the
  destinations are not disjoint, so `visible_bytes` says nothing of them.
-/

namespace MojoProofTest.Async

open MojoProof.Sem

/-- 16 bytes from global address 0 to shared address 0. -/
def c0 : AsyncCopy := ⟨0, 0, 16, 16⟩

/-- 16 bytes from global address 64 to shared address 16, of which 4 are read (`src-size` 4). -/
def c1 : AsyncCopy := ⟨16, 64, 16, 4⟩

/-- 8 bytes from global address 128 to shared address 32. -/
def c2 : AsyncCopy := ⟨32, 128, 8, 8⟩

/-- Copy `c0`, commit, copy `c1`, commit, copy `c2`. -/
def ops : List AsyncOp := [.copy c0, .commit, .copy c1, .commit, .copy c2]

/-- The copies of `ops` before its last commit are `c0`, `c1`; after it, `c2`. -/
theorem split : Async.committed ops = [c0, c1] ∧ Async.uncommitted ops = [c2] := by
  decide

/-- After `ops` and `wait_group 1`: `c2` uncommitted, the group `[c1]` pending, `c0` landed. -/
theorem wait1 : Async.init.run (ops ++ [.wait 1]) = ⟨[c2], [[c1]], [c0]⟩ := by
  decide

/-- The instance of `Async.wait_run` at `ops` and `wait_group 1`: at most one group is pending,
and the landed copies followed by the pending groups' copies are `c0`, `c1`. -/
theorem wait1_run : (Async.init.run (ops ++ [.wait 1])).groups.length ≤ 1 ∧
    (Async.init.run (ops ++ [.wait 1])).landed ++
        (Async.init.run (ops ++ [.wait 1])).groups.flatten = [c0, c1] :=
  ⟨(Async.wait_run ops 1).1, (Async.wait_run ops 1).2.trans split.1⟩

/-- The instance of `Async.visible` at `ops`: after `wait_group 0` no group is pending, `c0` and
`c1` have landed, in order, and `c2` is uncommitted. -/
theorem wait0 : (Async.init.run (ops ++ [.wait 0])).groups = [] ∧
    (Async.init.run (ops ++ [.wait 0])).landed = [c0, c1] ∧
    (Async.init.run (ops ++ [.wait 0])).pending = [c2] :=
  ⟨(Async.visible ops).1, (Async.visible ops).2.1.trans split.1,
    (Async.visible ops).2.2.trans split.2⟩

/-- The global memory whose byte `x` is `x % 256`. -/
def gm (x : Nat) : UInt8 := x.toUInt8

/-- The instance of `Async.visible_bytes` at `ops`, `gm` and a shared memory of `0xff` bytes:
after `wait_group 0`, byte 2 of `c1`'s destination is global byte 66, and byte 5 is 0, past its
`src-size` of 4. -/
theorem bytes : (Async.init.run (ops ++ [.wait 0])).smem gm (fun _ => 0xff) 18 = 66 ∧
    (Async.init.run (ops ++ [.wait 0])).smem gm (fun _ => 0xff) 21 = 0 := by
  have hd : (Async.committed ops).Pairwise AsyncCopy.Disjoint := by
    rw [split.1]
    simp [AsyncCopy.Disjoint, c0, c1]
  have hc : c1 ∈ Async.committed ops := by
    rw [split.1]
    simp
  exact ⟨(Async.visible_bytes ops gm _ hd hc (o := 2) (by decide)).trans (by decide),
    (Async.visible_bytes ops gm _ hd hc (o := 5) (by decide)).trans (by decide)⟩

/-- The twin: `c2` is issued after `ops`' last commit, so after `wait_group 0` its destination
still holds the initial `0xff`. -/
theorem bytes_twin : (Async.init.run (ops ++ [.wait 0])).smem gm (fun _ => 0xff) 32 = 0xff := by
  decide +kernel

/-- Two copies of 4 bytes to shared address 0, from global addresses 0 and 100, then a commit. -/
def twice : List AsyncOp := [.copy ⟨0, 0, 4, 4⟩, .copy ⟨0, 100, 4, 4⟩, .commit]

/-- The twin of `visible_bytes`' disjointness premise: the first copy of `twice` is committed,
the destinations of the committed copies are not disjoint, and after `wait_group 0` byte 0 of
shared memory is global byte 100, not the first copy's global byte 0. -/
theorem overlap : ⟨0, 0, 4, 4⟩ ∈ Async.committed twice ∧
    ¬ (Async.committed twice).Pairwise AsyncCopy.Disjoint ∧
    (Async.init.run (twice ++ [.wait 0])).smem gm (fun _ => 0xff) 0 = gm 100 ∧ gm 100 ≠ gm 0 := by
  have h : Async.committed twice = [⟨0, 0, 4, 4⟩, ⟨0, 100, 4, 4⟩] := by decide
  rw [h]
  refine ⟨by simp, by simp [AsyncCopy.Disjoint], by decide +kernel, by decide⟩

end MojoProofTest.Async
