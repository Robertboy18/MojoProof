import MojoProof.Sem.Async
import MojoProofTest.TensorCoreGpu

/-!
# A GPU run of `cp.async` and its groups against `Async.lazyRun` and `Async.smem`

`lake env lean --run tests/gpu/cp-async/Compare.lean <dump> <launches>` runs `main` on the dump
of tests/gpu/cp-async/test_async_cpy_wait_group.mojo: for each launch, the global words, the
initial shared words, the lanes' plans and the shared words each lane read back after
`cp.async.wait_group 1` and after `cp.async.wait_group 0`. Lane `l` issues 4 copies of 16 bytes,
copy `j` to the shared byte `64 l + 16 j` from the global byte and with the source size of its
plan (copy 3 without the `src-size` operand, so of size 16), in the groups `{0, 1}`, `{2}` and
`{3}`. For each lane it evaluates `Async.smem` after `Async.lazyRun` of those operations from
`Async.init`, with the dumped global and initial shared bytes (little-endian words): after
`wait 1` at the 48 bytes of the two older groups, after `wait 0` at all 64, and compares the
GPU's words with the model's word for word. After `wait 0` every run of the model gives the
lazy run's bytes (`wait0_bytes`, from `Async.visible_bytes`: the copies' destinations are
disjoint, `ops_disjoint`). After `wait 1` every run gives them at the 48 bytes of the two older
groups (`wait1_bytes`, from `Async.determined`), but not at the bytes of copy 3, which may still
be pending (`wait1_pending`).

It refuses a dump with a malformed case, with no launch, or with a number of launches other than
`<launches>` (`TensorCoreGpu.launches`, exit code 2). Exit code 0 when every word agrees and the
GPU wrote every word (none is the initial word of the output buffers); 1 otherwise.

A conformance test of one instruction and its groups on these inputs and one GPU, not a proof.
-/

namespace MojoProofTest.AsyncGpu

open MojoProof.Sem
open MojoProofTest.TensorCoreGpu (nums numsOf launches)

/-- One launch of the dump: the global words, the initial shared words, the lanes' plans, the
word the output buffers held before the launch, and the words the lanes read back after
`wait_group 1` (12 to a lane) and after `wait_group 0` (16 to a lane). -/
structure Case where
  /-- The launch from its global words, shared words, plans, fill word and words read back. -/
  mk ::
  /-- The 1,024 global words, the byte at `x` in bits `8 (x % 4)` of word `x / 4`. -/
  gm : Array Nat
  /-- The 512 shared words before the copies, laid out as `gm`. -/
  init : Array Nat
  /-- The plans, 8 words to a lane: copy `j`'s global byte offset, then its source size. -/
  plan : Array Nat
  /-- Every word of the output buffers before the launch. -/
  fill : Nat
  /-- The words read after `wait_group 1`, 12 to a lane. -/
  wait1 : Array Nat
  /-- The words read after `wait_group 0`, 16 to a lane. -/
  wait0 : Array Nat

/-- The cases of the dump's lines: each line `case n` starts one, followed by its lines `gm`
(1,024 words), `init` (512), `plan` (256), `fill` (one word), `wait1` (384) and `wait0` (512);
other lines are skipped. -/
def parse : List String → Except String (List Case)
  | [] => pure []
  | l :: ls =>
    if l.startsWith "case" then
      match ls with
      | lg :: li :: lp :: lf :: l1 :: l0 :: rest => do
        let [f] ← nums "fill" lf | throw s!"fill: {lf}"
        let c : Case := ⟨← numsOf "gm" 1024 lg, ← numsOf "init" 512 li, ← numsOf "plan" 256 lp,
          f, ← numsOf "wait1" 384 l1, ← numsOf "wait0" 512 l0⟩
        return c :: (← parse rest)
      | _ => throw s!"a truncated case: {l}"
    else parse ls

/-- Byte `x` of the little-endian words `w` (`0` past the end). -/
def byte (w : Array Nat) (x : Nat) : UInt8 :=
  (w.getD (x / 4) 0 / 2 ^ (8 * (x % 4)) % 256).toUInt8

/-- Copy `j` of lane `l` in the case `c`: 16 bytes to the shared byte `64 l + 16 j`, from the
global byte and with the source size of the lane's plan. -/
def copyOf (c : Case) (l j : Nat) : AsyncCopy :=
  ⟨64 * l + 16 * j, c.plan.getD (8 * l + 2 * j) 0, 16, c.plan.getD (8 * l + 2 * j + 1) 0⟩

/-- Lane `l`'s operations in the case `c` up to `wait_group 1`: copies 0 and 1, a commit, copy
2, a commit, copy 3, a commit, `wait 1`. -/
def ops (c : Case) (l : Nat) : List AsyncOp :=
  [.copy (copyOf c l 0), .copy (copyOf c l 1), .commit, .copy (copyOf c l 2), .commit,
    .copy (copyOf c l 3), .commit, .wait 1]

/-- The copies of lane `l`'s operations in the case `c` have pairwise disjoint destinations, for
every case and lane: copy `j` writes the bytes `64 l + 16 j` to `64 l + 16 j + 15`. -/
theorem ops_disjoint (c : Case) (l : Nat) :
    ((ops c l).filterMap AsyncOp.copy?).Pairwise AsyncCopy.Disjoint := by
  rw [show (ops c l).filterMap AsyncOp.copy? = [0, 1, 2, 3].map (copyOf c l) from rfl]
  simp [copyOf, AsyncCopy.Disjoint]

/-- **Every run of a lane's operations and `wait_group 0` gives the bytes the comparison
checks**, for every case `c`, lane `l`, initial shared memory `sm`, run `t` of `ops c l` and
`wait 0` from `Async.init`, copy `d` of the lane and offset `o < d.size`: the shared memory holds
at `d.dst + o` the global byte `byte c.gm (d.src + o)` when `o < d.srcSize`, and `0` otherwise,
as in the lazy run. `Async.visible_bytes` with `ops_disjoint`. -/
theorem wait0_bytes (c : Case) (l : Nat) (sm : Nat → UInt8) {t : Async}
    (h : Async.Run Async.init (ops c l ++ [.wait 0]) t) {d : AsyncCopy}
    (hd : d ∈ (ops c l).filterMap AsyncOp.copy?) {o : Nat} (ho : o < d.size) :
    t.smem (byte c.gm) sm (d.dst + o) = if o < d.srcSize then byte c.gm (d.src + o) else 0 :=
  Async.visible_bytes _ _ _ (ops_disjoint c l) (c := d) hd ho h

/-- **Every run of a lane's operations up to `wait_group 1` gives the bytes the comparison checks
after it**, for every case `c`, lane `l`, initial shared memory `sm`, run `t` of `ops c l` from
`Async.init`, word `i < 12` of the lane and byte `k < 4` of it: the shared memory holds at
`64 l + 4 i + k` the lazy run's byte. `Async.determined`, with `ops_disjoint` for both premises:
no copy is issued while a copy issued before it and not landed writes its bytes, and copy 3, which
may still be pending, writes none of these bytes, since copy `i / 4` writes them and its
destination is disjoint from copy 3's. -/
theorem wait1_bytes (c : Case) (l : Nat) (sm : Nat → UInt8) {t : Async}
    (h : Async.Run Async.init (ops c l) t) {i k : Nat} (hi : i < 12) (hk : k < 4) :
    t.smem (byte c.gm) sm (64 * l + 4 * i + k) =
      (Async.init.lazyRun (ops c l)).smem (byte c.gm) sm (64 * l + 4 * i + k) := by
  refine Async.determined _ _ _ _ ?_ ?_ h
  · intro p d q hpq ⟨h1, h2⟩ e he ⟨h3, h4⟩
    have hd := ops_disjoint c l
    have hf : (p ++ .copy d :: q).filterMap AsyncOp.copy? =
        p.filterMap AsyncOp.copy? ++ d :: q.filterMap AsyncOp.copy? := by
      simp [AsyncOp.copy?]
    rw [hpq, hf, List.pairwise_append] at hd
    have hp : e ∈ p.filterMap AsyncOp.copy? := by
      obtain ⟨hl, hu⟩ := Async.lazyRun_init p
      have hcu : e ∈ Async.committed p ∨ e ∈ Async.uncommitted p := by
        rw [← hl, ← hu]
        simp only [Async.unlanded, List.mem_append] at he ⊢
        tauto
      rcases hcu with hc | hc
      · simp only [Async.committed] at hc
        obtain ⟨a, ha, hca⟩ := List.mem_filterMap.1 hc
        exact List.mem_filterMap.2
          ⟨a, List.mem_reverse.1 ((List.dropWhile_suffix _).subset (List.mem_reverse.1 ha)), hca⟩
      · simp only [Async.uncommitted] at hc
        obtain ⟨a, ha, hca⟩ := List.mem_filterMap.1 hc
        exact List.mem_filterMap.2
          ⟨a, List.mem_reverse.1 ((List.takeWhile_prefix _).subset (List.mem_reverse.1 ha)), hca⟩
    rcases hd.2.2 e hp d List.mem_cons_self with h | h <;> omega
  · intro e he ⟨h3, h4⟩
    have hu : (Async.init.lazyRun (ops c l)).unlanded = [copyOf c l 3] := rfl
    rw [hu, List.mem_singleton] at he
    subst he
    have hd := ops_disjoint c l
    rw [show (ops c l).filterMap AsyncOp.copy? =
      [copyOf c l 0, copyOf c l 1, copyOf c l 2, copyOf c l 3] from rfl,
      List.pairwise_iff_getElem] at hd
    have hw : (copyOf c l (i / 4)).Writes (64 * l + 4 * i + k) := by
      simp only [copyOf, AsyncCopy.Writes]
      omega
    have hj : AsyncCopy.Disjoint (copyOf c l (i / 4)) (copyOf c l 3) := by
      obtain h | h | h : i / 4 = 0 ∨ i / 4 = 1 ∨ i / 4 = 2 := by omega
      · rw [h]; exact hd 0 3 (by simp) (by simp) (by omega)
      · rw [h]; exact hd 1 3 (by simp) (by simp) (by omega)
      · rw [h]; exact hd 2 3 (by simp) (by simp) (by omega)
    obtain ⟨h1, h2⟩ := hw
    rcases hj with h | h <;> omega

/-- **The bytes copy 3 writes are not determined after `wait_group 1`**, the twin of
`wait1_bytes`'s premise `i < 12`: for every case `c`, lane `l`, word `12 ≤ i < 16` and byte
`k < 4`, some initial shared memory and some run of `ops c l` (the lazy run, then copy 3 landing)
give at `64 l + 4 i + k` a byte other than the lazy run's, in which copy 3 is still pending. -/
theorem wait1_pending (c : Case) (l : Nat) {i k : Nat} (hi : 12 ≤ i) (hi' : i < 16)
    (hk : k < 4) :
    ∃ (sm : Nat → UInt8) (t : Async), Async.Run Async.init (ops c l) t ∧
      t.smem (byte c.gm) sm (64 * l + 4 * i + k) ≠
        (Async.init.lazyRun (ops c l)).smem (byte c.gm) sm (64 * l + 4 * i + k) := by
  have e : Async.init.lazyRun (ops c l) =
      ⟨[], [[copyOf c l 3]], [copyOf c l 0, copyOf c l 1, copyOf c l 2]⟩ := rfl
  have w3 : (copyOf c l 3).Writes (64 * l + 4 * i + k) := by
    simp only [copyOf, AsyncCopy.Writes]
    omega
  have w : ∀ j < 3, ¬ (copyOf c l j).Writes (64 * l + 4 * i + k) := by
    intro j hj
    simp only [copyOf, AsyncCopy.Writes]
    omega
  obtain ⟨v, hv⟩ : ∃ v, v = (copyOf c l 3).land (byte c.gm) (fun _ => 0) (64 * l + 4 * i + k) :=
    ⟨_, rfl⟩
  refine ⟨fun _ => if v = 0 then 1 else 0,
    ⟨[], [[]], [copyOf c l 0, copyOf c l 1, copyOf c l 2, copyOf c l 3]⟩, ?_, ?_⟩
  · have h := Async.Run.lazy Async.init (ops c l)
    rw [e] at h
    exact .land h (.landGroup [] [] [] [] [] (copyOf c l 3) _)
  · rw [e]
    simp only [Async.smem, List.foldl_cons, List.foldl_nil, AsyncCopy.land, eq_true w3,
      eq_false (w 0 (by omega)), eq_false (w 1 (by omega)), eq_false (w 2 (by omega)),
      ↓reduceIte]
    simp only [AsyncCopy.land, eq_true w3, ↓reduceIte] at hv
    rw [← hv]
    by_cases h0 : v = 0 <;> simp [h0]

/-- The model's word `i` of lane `l`'s 64 bytes in the case `c` after the operations `os`: the
shared bytes `64 l + 4 i` to `64 l + 4 i + 3` of `Async.smem` after `Async.lazyRun` of `os`
from `Async.init`, little-endian. -/
def model (c : Case) (os : List AsyncOp) (l i : Nat) : Nat :=
  let m := Async.smem (byte c.gm) (byte c.init) (Async.lazyRun Async.init os)
  (List.range 4).foldr (fun k w => (m (64 * l + 4 * i + k)).toNat + 256 * w) 0

/-- The pairs `(lane, word)` of the case `c` where the GPU's words differ from the model's:
after `wait_group 1` (words 0 to 11 of each lane) when `w0` is false, after `wait_group 0`
(words 0 to 15) when it is true. -/
def diff (c : Case) (w0 : Bool) : List (Nat × Nat) :=
  let n := if w0 then 16 else 12
  ((List.range 32).flatMap fun l => (List.range n).map fun i => (l, i)).filter fun (l, i) =>
    (if w0 then c.wait0 else c.wait1).getD (n * l + i) 0 ≠
      model c (if w0 then ops c l ++ [.wait 0] else ops c l) l i

/-- Compares every case of `cs` and prints a line for each, the first differing words, and a
summary; exit code 0 when every word agrees and none is left at the initial word, 1
otherwise. -/
def compare (cs : List Case) : IO UInt32 := do
  let mut bad := 0
  let mut left := 0
  for (c, n) in cs.zipIdx do
    let p := diff c false
    let q := diff c true
    let u := (c.wait1.toList ++ c.wait0.toList).filter (· = c.fill) |>.length
    IO.println s!"case {n}: after wait_group 1 {384 - p.length} of 384 words agree, after \
      wait_group 0 {512 - q.length} of 512 agree, {u} words unwritten"
    for (l, i) in p.take 4 do
      IO.println s!"case {n} wait_group 1 lane {l} word {i}: GPU {c.wait1.getD (12 * l + i) 0}, \
        model {model c (ops c l) l i}"
    for (l, i) in q.take 4 do
      IO.println s!"case {n} wait_group 0 lane {l} word {i}: GPU {c.wait0.getD (16 * l + i) 0}, \
        model {model c (ops c l ++ [.wait 0]) l i}"
    bad := bad + p.length + q.length
    left := left + u
  IO.println s!"{cs.length} launches: {bad} words differ, {left} words unwritten"
  return if bad = 0 ∧ left = 0 then 0 else 1

/-- The entry point: `<dump> <launches>`; refuses a malformed dump, one with no launch or another
number of launches (`TensorCoreGpu.launches`, exit code 2), else `compare`. -/
def main (args : List String) : IO UInt32 := do
  let [path, count] := args
    | IO.eprintln "usage: lean --run tests/gpu/cp-async/Compare.lean <dump> <launches>"; return 2
  let some expected := count.toNat?
    | IO.eprintln s!"not a number of launches: {count}"; return 2
  match launches parse (← IO.FS.lines path).toList expected with
  | .error e => IO.eprintln s!"{path}: {e}"; return 2
  | .ok cs => compare cs

/-- A made-up case: global word `i` is `i`, the shared words and the output buffers' word
`0x7fbadbad`, lane `l`'s copy `j` from byte `16 (4 l + j)` with source size 16, so lane `l`'s
word `i` is `16 l + i` after `wait 0`; and the same with lane 0's copy 1 of source size 5. -/
private def inOrder (s : Nat) : Case :=
  ⟨.ofFn (n := 1024) (·.val), .replicate 512 0x7fbadbad,
    .ofFn (n := 256) fun i =>
      if i.val % 2 = 0 then 16 * (4 * (i.val / 8) + i.val % 8 / 2)
      else if i.val = 3 then s else 16,
    0x7fbadbad, .ofFn (n := 384) fun i => 16 * (i.val / 12) + i.val % 12,
    .ofFn (n := 512) (·.val)⟩

-- The model's words are the made-up case's.
#guard (diff (inOrder 16) false).isEmpty && (diff (inOrder 16) true).isEmpty
-- With source size 5, lane 0's copy 1 reads global word 4 and the low byte of word 5 (which is
-- all of word 5) and writes zeros for words 6 and 7: those two differ after `wait 0`.
#guard (diff (inOrder 5) true).map (·.2) == [6, 7]

end MojoProofTest.AsyncGpu
