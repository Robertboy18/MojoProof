import MojoProof.Sem.Async

/-!
# Asynchronous copies: sequences of copies, commits and waits under every completion choice

Tests of MojoProof/Sem/Async.lean on the operations `ops`: copy `c0` (16 bytes from global
address 0 to shared address 0), commit, copy `c1` (16 bytes from global 64 to shared 16, of which
4 are read: `src-size` 4), commit, copy `c2` (8 bytes from global 128 to shared 32), and no commit
after it.
* `split`: `committed ops` is `[c0, c1]` and `uncommitted ops` is `[c2]`.
* `wait1`: after `wait_group 1`, under the lazy completion choice, `c0` has landed, the group of
  `c1` is pending and `c2` is uncommitted, by evaluation; `wait1_run`: the instance of `wait_run`
  there, for every run.
* `wait0`: the instance of `visible`: after `wait_group 0`, in every run `c0` and `c1` have
  landed and at most `c2` has not.
* `bytes`: the instance of `visible_bytes`, with global byte `x` equal to `x % 256` (`gm`) and a
  shared memory of `0xff` bytes: in every run, byte 2 of `c1`'s destination is global byte 66,
  and byte 5 is 0, past `src-size`.
* The boundary twins `boundary` and `own`: byte 32, `c2`'s first, after `wait_group 0` holds
  `0xff` in one run and `c2`'s byte 128 in another, as `c2` is not waited for; once `c2`'s own
  group is committed and waited for, it is 128 in every run.
* `reused`: the instance of `determined` on a buffer written, waited for, and written again: its
  byte is the second copy's in every run.
* The twin `overlap`: two copies to the same 4 bytes, from global addresses 0 and 100, in one
  group: after `wait_group 0` byte 0 is global byte 100 in one run and global byte 0 in another,
  so neither `visible_bytes` (destinations not disjoint) nor `determined` (the second copy is
  issued while the first may be pending) can say more.
-/

namespace MojoProofTest.Async

open MojoProof.Sem
open scoped List

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

/-- After `ops` and `wait_group 1` under the lazy completion choice: `c2` uncommitted, the group
`[c1]` pending, `c0` landed. -/
theorem wait1 : Async.init.lazyRun (ops ++ [.wait 1]) = ⟨[c2], [[c1]], [c0]⟩ := by
  decide

/-- The instance of `Async.wait_run` at `ops` and `wait_group 1`: in every run at most one group
is pending and `c0` has landed. -/
theorem wait1_run {t : Async} (h : Async.Run Async.init (ops ++ [.wait 1]) t) :
    t.groups.length ≤ 1 ∧ [c0] <+~ t.landed := by
  have := Async.wait_run ops 1 h
  rw [wait1] at this
  exact this

/-- The instance of `Async.visible` at `ops`: after `wait_group 0`, in every run no group is
pending, `c0` and `c1` have landed, and the uncommitted copies are `c2` or none. -/
theorem wait0 {t : Async} (h : Async.Run Async.init (ops ++ [.wait 0]) t) :
    t.groups = [] ∧ [c0, c1] <+~ t.landed ∧ t.pending <+ [c2] := by
  have := Async.visible ops h
  rw [split.1, split.2] at this
  exact this

/-- The global memory whose byte `x` is `x % 256`. -/
def gm (x : Nat) : UInt8 := x.toUInt8

/-- The destinations of `ops`' copies are pairwise disjoint. -/
theorem disjoint : (ops.filterMap AsyncOp.copy?).Pairwise AsyncCopy.Disjoint := by
  rw [show ops.filterMap AsyncOp.copy? = [c0, c1, c2] from rfl]
  simp [AsyncCopy.Disjoint, c0, c1, c2]

/-- The instance of `Async.visible_bytes` at `ops`, `gm` and a shared memory of `0xff` bytes:
after `wait_group 0`, in every run byte 2 of `c1`'s destination is global byte 66, and byte 5 is
0, past its `src-size` of 4. -/
theorem bytes {t : Async} (h : Async.Run Async.init (ops ++ [.wait 0]) t) :
    t.smem gm (fun _ => 0xff) 18 = 66 ∧ t.smem gm (fun _ => 0xff) 21 = 0 := by
  have hc : c1 ∈ Async.committed ops := by
    rw [split.1]
    simp
  exact ⟨(Async.visible_bytes ops gm _ disjoint hc (o := 2) (by decide) h).trans (by decide),
    (Async.visible_bytes ops gm _ disjoint hc (o := 5) (by decide) h).trans (by decide)⟩

/-- The boundary twins at byte 32, `c2`'s first: `c2` is issued after `ops`' last commit, so
after `wait_group 0`, which waits only for the earlier groups, the byte holds the initial `0xff`
in one run (the lazy completion choice) and `c2`'s global byte 128 in another (`c2` lands after
the wait); both runs exist. -/
theorem boundary : ∃ t₁ t₂, Async.Run Async.init (ops ++ [.wait 0]) t₁ ∧
    Async.Run Async.init (ops ++ [.wait 0]) t₂ ∧
    t₁.smem gm (fun _ => 0xff) 32 = 0xff ∧ t₂.smem gm (fun _ => 0xff) 32 = 128 := by
  have e : Async.init.lazyRun (ops ++ [.wait 0]) = ⟨[] ++ c2 :: [], [], [c0, c1]⟩ := by decide
  have r := Async.Run.lazy Async.init (ops ++ [.wait 0])
  rw [e] at r
  exact ⟨_, _, r, .land r (.landPending [] [] c2 [] [c0, c1]), by decide +kernel,
    by decide +kernel⟩

/-- The other side of the boundary: once `c2`'s own group is committed and waited for, byte 32
is `c2`'s global byte 128 in every run, the instance of `Async.visible_bytes` at `ops` followed by
a commit. -/
theorem own {t : Async} (h : Async.Run Async.init ((ops ++ [AsyncOp.commit]) ++ [.wait 0]) t) :
    t.smem gm (fun _ => 0xff) 32 = 128 := by
  have hd : ((ops ++ [AsyncOp.commit]).filterMap AsyncOp.copy?).Pairwise AsyncCopy.Disjoint :=
    disjoint
  have hc : c2 ∈ Async.committed (ops ++ [AsyncOp.commit]) := by decide
  exact (Async.visible_bytes _ gm _ hd hc (o := 0) (by decide) h).trans (by decide)

/-- 4 bytes from global address `a` to shared address 0. -/
def at0 (a : Nat) : AsyncCopy := ⟨0, a, 4, 4⟩

/-- A buffer reused after a wait: copy from global address 0 to shared bytes 0 to 3, commit,
wait for it, then copy from global address 100 to the same bytes, commit, and wait again. -/
def reuse : List AsyncOp := [.copy (at0 0), .commit, .wait 0, .copy (at0 100), .commit, .wait 0]

/-- The instance of `Async.determined` at `reuse` and byte 0: both copies write it, but the
second is issued after a wait for the first, so in every run byte 0 is the second copy's global
byte 100. -/
theorem reused {t : Async} (h : Async.Run Async.init reuse t) :
    t.smem gm (fun _ => 0xff) 0 = gm 100 := by
  refine (Async.determined reuse gm _ 0 ?_ (by decide) h).trans (by decide +kernel)
  intro p c q hp _ d hd
  rcases p with _ | ⟨o₁, _ | ⟨o₂, _ | ⟨o₃, _ | ⟨o₄, _ | ⟨o₅, _ | ⟨o₆, p⟩⟩⟩⟩⟩⟩ <;>
    simp [reuse] at hp
  · simp [Async.init, Async.lazyRun, Async.unlanded] at hd
  · obtain ⟨rfl, rfl, rfl, -⟩ := hp
    simp [Async.init, Async.lazyRun, Async.lazy, Async.unlanded] at hd

/-- Two copies of 4 bytes to shared address 0, from global addresses 0 and 100, then a commit. -/
def twice : List AsyncOp := [.copy (at0 0), .copy (at0 100), .commit]

/-- The twin of the premises of `visible_bytes` (disjoint destinations) and `determined` (a
byte written again only after a wait for its previous writer): the destinations of `twice`'s
copies overlap, and after `wait_group 0` byte 0 is global byte 100 in one run (the copies land in
issue order) and global byte 0 in another (the second lands first). -/
theorem overlap : ¬ (twice.filterMap AsyncOp.copy?).Pairwise AsyncCopy.Disjoint ∧
    ∃ t₁ t₂, Async.Run Async.init (twice ++ [.wait 0]) t₁ ∧
      Async.Run Async.init (twice ++ [.wait 0]) t₂ ∧
      t₁.smem gm (fun _ => 0xff) 0 = gm 100 ∧ t₂.smem gm (fun _ => 0xff) 0 = gm 0 ∧
      gm 100 ≠ gm 0 := by
  have r1 := Async.Run.op (Async.Run.nil (s := Async.init)) (.copy _ (at0 0))
  have r2 := Async.Run.op r1 (.copy _ (at0 100))
  have r3 := Async.Run.land r2 (.landPending [at0 0] [] (at0 100) [] [])
  have r4 := Async.Run.land r3 (.landPending [] [] (at0 0) [] [at0 100])
  have r5 := Async.Run.op r4 (.commit _)
  have r6 := Async.Run.op r5 (.wait _ 0 (by decide))
  exact ⟨by simp [twice, AsyncOp.copy?, AsyncCopy.Disjoint, at0], _, _,
    Async.Run.lazy _ _, r6, by decide +kernel, by decide +kernel, by decide⟩

end MojoProofTest.Async
