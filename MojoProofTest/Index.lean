import MojoProof.Sem.Index

/-!
# Instance and twin of the global thread index

The instance, one launch: grid (2, 1, 1) and block (4, 1, 1) (`launch2 2 1 4 1`), valid (`valid24`).
By the library theorems, for each of its 8 threads the IR's operations on the special registers'
words give the i64 word of the thread number (`index24`: `Launch.index_ops` and
`Launch.index_oneDim`), and so does the evaluation of the same five operations (`eval24`, by
`decide`). Two threads with equal index words are one thread (`inj24`, `Launch.index_inj`). For each
index below 8, `trunc` to i32 and `sext` back give its i64 word (`roundtrip24`,
`intCast_trunc_sext`); at `2 ^ 31` they do not (`roundtrip_twin`).

The twin, one launch: grid (1, 1, 1) and block (2, 2, 1) (`launch2 1 1 2 2`, valid), a 2-D block.
Thread 2 has `tid` (0, 1), so its `ctaid.x * ntid.x + tid.x` is 0, not 2, and is that of thread 0
(`twin22`): `Launch.index_oneDim` needs its premise on the block, and on this launch the index is
not injective on thread numbers, though `Launch.index_inj` still gives equal `ctaid.x` and `tid.x`.

On 2-D launches, one launch each: grid and block (2, 2, 1) (`launch2 2 2 2 2`, valid, 16 threads).
Its cells `row * 4 + col` are 0 to 15, each once, and every column is below 4 (`cells2222`, by
evaluation); the 4-byte cells `(row * 4 + col) * 4` of distinct threads are 4 bytes apart
(`apart2222`, `Launch.cell_apart`), and equal row and column words are one thread (`inj2222`,
`Launch.xy_inj`). The twins: on grid (1, 1, 1) and block (1, 1, 2) (`L112`, valid), threads 0 and
1 have row 0 and column 0 (`twin112`), so `Launch.xy_inj` needs side 1 in `z`; on `launch2 2 2 2 2`
with stride 1, threads 1 (row 1, column 0) and 2 (row 0, column 1) have cell 1 (`twin_stride`), so
`Launch.cell_inj` needs the columns below the stride.

Every cell is some thread's, on `launch2 2 2 2 2`: each `(r, c)` with `r, c < 4` is the row and
column of a thread below 16 (`onto2222`, `Launch.cell_onto`); cell `(3, 2)` is thread 13's
(`cell32`, by evaluation). The twin: no thread has row 4 or column 4 (`twin_onto`,
`Launch.index_lt_mul`), so `Launch.cell_onto` needs its bounds.
-/

namespace MojoProofTest.Index

open MojoProof.Sem MojoProof.LLVM

/-- The launch of grid (2, 1, 1) and block (4, 1, 1) is valid. -/
theorem valid24 : (launch2 2 1 4 1).Valid := launch2_valid (by decide)

/-- The IR's index of thread `n` of `L`, by evaluation of the five operations with no flags:
`zext` of `tid.x` and `ctaid.x`, `sext` of `ntid.x`, `mul`, `add`; `none` if one fails. -/
def evalIndex (L : Launch) (n : Nat) : Option (BitVec 64) :=
  let w (r : SReg) : Val := .bits 32 (BitVec.ofNat 32 ((L.env n).sreg r .x))
  match (do
      let t ← intCast .zext 64 (w .tid)
      let b ← intCast .zext 64 (w .ctaid)
      let k ← intCast .sext 64 (w .ntid)
      let p ← intBin 64 .mul {} b k
      intBin 64 .add {} p t : Except Fault Val) with
  | .ok (.bits 64 v) => some v
  | _ => none

/-- **The instance, by the library theorems**: for each thread `n < 8` of `launch2 2 1 4 1` and all
flags `fl` (of the `mul`) and `fl'` (of the `add`), the five operations (`zext` of the i32 words of
`tid.x` and `ctaid.x`, `sext` of that of `ntid.x`, their `mul`, then the `add` of `tid.x`) give the
i64 word of `n` (`Launch.index_ops`, `Launch.index_oneDim`). -/
theorem index24 (fl fl' : IntFlags) {n : Nat} (hn : n < 8) :
    (do
      let t ← intCast .zext 64
        (.bits 32 (BitVec.ofNat 32 (((launch2 2 1 4 1).env n).sreg .tid .x)))
      let b ← intCast .zext 64
        (.bits 32 (BitVec.ofNat 32 (((launch2 2 1 4 1).env n).sreg .ctaid .x)))
      let k ← intCast .sext 64
        (.bits 32 (BitVec.ofNat 32 (((launch2 2 1 4 1).env n).sreg .ntid .x)))
      let p ← intBin 64 .mul fl b k
      intBin 64 .add fl' p t : Except Fault Val) = .ok (.bits 64 (BitVec.ofNat 64 n)) := by
  obtain ⟨h1, h2, h3, h4, h5⟩ := Launch.index_ops valid24 n .x fl fl'
  rw [Launch.index_oneDim ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by simpa [volume, launch2] using hn)] at h5
  simp only [h1, h2, h3, h4, h5, bind, Except.bind]

/-- **The instance, by evaluation**: for each thread `n < 8` of `launch2 2 1 4 1` the five
operations give the i64 word of `n`. -/
theorem eval24 :
    (List.range 8).all (fun n => evalIndex (launch2 2 1 4 1) n == some (BitVec.ofNat 64 n)) =
      true := by
  decide +kernel

/-- The instance of `Launch.index_inj`: on `launch2 2 1 4 1`, threads below 8 with equal index words
are one thread. -/
theorem inj24 {n n' : Nat} (hn : n < 8) (hn' : n' < 8)
    (he : BitVec.ofNat 64
        (((launch2 2 1 4 1).env n).sreg .ctaid .x * ((launch2 2 1 4 1).env n).sreg .ntid .x +
          ((launch2 2 1 4 1).env n).sreg .tid .x) =
      BitVec.ofNat 64
        (((launch2 2 1 4 1).env n').sreg .ctaid .x * ((launch2 2 1 4 1).env n').sreg .ntid .x +
          ((launch2 2 1 4 1).env n').sreg .tid .x)) :
    n = n' := by
  obtain ⟨hc, ht⟩ := Launch.index_inj valid24 .x he
  have e := Launch.index_oneDim (L := launch2 2 1 4 1) ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (n := n)
    (by simpa [volume, launch2] using hn)
  have e' := Launch.index_oneDim (L := launch2 2 1 4 1) ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (n := n')
    (by simpa [volume, launch2] using hn')
  rw [hc, ht] at e
  exact e.symm.trans e'

/-- The instance of `intCast_trunc_sext` (the vector kernel's `%22`, `%23`): for each index
`n < 8` of `launch2 2 1 4 1`, `trunc` to i32 and `sext` back give the i64 word of `n`. -/
theorem roundtrip24 {n : Nat} (hn : n < 8) :
    intCast .trunc 32 (.bits 64 (BitVec.ofNat 64 n)) = .ok (.bits 32 (BitVec.ofNat 32 n)) ∧
      intCast .sext 64 (.bits 32 (BitVec.ofNat 32 n)) = .ok (.bits 64 (BitVec.ofNat 64 n)) :=
  intCast_trunc_sext (by decide) (by omega)

/-- The twin of `roundtrip24`: at `2 ^ 31` the sign bit of the i32 word is set, so `sext` back
gives the i64 word of `2 ^ 64 - 2 ^ 31`, not of `2 ^ 31`. -/
theorem roundtrip_twin :
    intCast .trunc 32 (.bits 64 (BitVec.ofNat 64 (2 ^ 31))) =
        .ok (.bits 32 (BitVec.ofNat 32 (2 ^ 31))) ∧
      intCast .sext 64 (.bits 32 (BitVec.ofNat 32 (2 ^ 31))) =
        .ok (.bits 64 (BitVec.ofNat 64 (2 ^ 64 - 2 ^ 31))) ∧
      BitVec.ofNat 64 (2 ^ 64 - 2 ^ 31) ≠ BitVec.ofNat 64 (2 ^ 31) :=
  ⟨rfl, rfl, by decide⟩

/-- **The twin**: `launch2 1 1 2 2` (grid (1, 1, 1) and block (2, 2, 1)) is valid and has 4 threads,
but thread 2's `ctaid.x * ntid.x + tid.x` is 0, that of thread 0, so on a 2-D block the index is not
the thread number and not injective on thread numbers; its `ctaid.x` and `tid.x` are those of thread
0, as `Launch.index_inj` says. -/
theorem twin22 : (launch2 1 1 2 2).Valid ∧
    volume (launch2 1 1 2 2).grid * volume (launch2 1 1 2 2).block = 4 ∧
    ((launch2 1 1 2 2).env 2).sreg .ctaid .x * ((launch2 1 1 2 2).env 2).sreg .ntid .x +
      ((launch2 1 1 2 2).env 2).sreg .tid .x = 0 ∧
    ((launch2 1 1 2 2).env 0).sreg .ctaid .x * ((launch2 1 1 2 2).env 0).sreg .ntid .x +
      ((launch2 1 1 2 2).env 0).sreg .tid .x = 0 ∧
    ((launch2 1 1 2 2).env 2).sreg .tid .y = 1 ∧ evalIndex (launch2 1 1 2 2) 2 = some 0 :=
  ⟨launch2_valid (by decide), rfl, rfl, rfl, rfl, by decide +kernel⟩

/-- The byte offset `(row * 4 + col) * 4` of thread `n`'s 4-byte cell on `launch2 2 2 2 2`, from
offset 0. -/
def cell2222 (n : Nat) : Nat :=
  ((launch2 2 2 2 2).index n .x * 4 + (launch2 2 2 2 2).index n .y) * 4

/-- On `launch2 2 2 2 2`, by evaluation: the launch has 16 threads, their cells `row * 4 + col`
(`cell2222 n / 4`: `Launch.index` in `x`, then in `y`) are 0 to 15, each once, in the order listed,
and every column is below 4. -/
theorem cells2222 : volume (launch2 2 2 2 2).grid * volume (launch2 2 2 2 2).block = 16 ∧
    (List.range 16).map (fun n => cell2222 n / 4) =
      [0, 4, 1, 5, 8, 12, 9, 13, 2, 6, 3, 7, 10, 14, 11, 15] ∧
    ((List.range 16).map fun n => cell2222 n / 4).Nodup ∧
    ∀ n < 16, (launch2 2 2 2 2).index n .y < 4 := by
  decide +kernel

/-- The instance of `Launch.cell_apart` (stride 4, base 0, width 4, the threads below 16): on
`launch2 2 2 2 2` the cells `cell2222` of distinct threads are 4 bytes apart. -/
theorem apart2222 : ∀ n n', n ≠ n' → n < 16 → n' < 16 →
    cell2222 n + 4 ≤ cell2222 n' ∨ cell2222 n' + 4 ≤ cell2222 n := fun n n' hne h1 h2 => by
  have := Launch.cell_apart (launch2_valid (by decide)) (L := launch2 2 2 2 2) ⟨rfl, rfl⟩ (s := 4)
    (p := (· < 16))
    (fun n hn => ⟨by simpa [volume, launch2] using hn, cells2222.2.2.2 n hn⟩) 0 4 n n'
    hne h1 h2
  simpa only [cell2222, Nat.zero_add] using this

/-- The instance of `Launch.xy_inj`: on `launch2 2 2 2 2`, threads below 16 with equal i64 words of
the row and of the column (`Launch.index` in `x` and in `y`) are one thread. -/
theorem inj2222 {n n' : Nat} (hn : n < 16) (hn' : n' < 16)
    (hx : BitVec.ofNat 64 ((launch2 2 2 2 2).index n .x) =
      BitVec.ofNat 64 ((launch2 2 2 2 2).index n' .x))
    (hy : BitVec.ofNat 64 ((launch2 2 2 2 2).index n .y) =
      BitVec.ofNat 64 ((launch2 2 2 2 2).index n' .y)) : n = n' :=
  Launch.xy_inj (launch2_valid (by decide)) (L := launch2 2 2 2 2) ⟨rfl, rfl⟩
    (by simpa [volume, launch2] using hn) (by simpa [volume, launch2] using hn') hx hy

/-- The launch of grid (1, 1, 1) and block (1, 1, 2). -/
def L112 : Launch := ⟨fun _ => 1, fun | .z => 2 | _ => 1, 0, gridAcc⟩

/-- **The twin of the `z` premise**: `L112` is valid and has 2 threads, and threads 0 and 1 both
have row 0 and column 0 (`Launch.index` in `x` and `y`) but `z` indices 0 and 1, so equal row
and column words do not give one thread without side 1 in `z` (`Launch.xy_inj`'s premise). -/
theorem twin112 : L112.Valid ∧ volume L112.grid * volume L112.block = 2 ∧
    L112.index 0 .x = 0 ∧ L112.index 1 .x = 0 ∧ L112.index 0 .y = 0 ∧ L112.index 1 .y = 0 ∧
    L112.index 0 .z = 0 ∧ L112.index 1 .z = 1 :=
  ⟨⟨fun d => by cases d <;> decide, fun d => by cases d <;> decide,
    fun d => by cases d <;> decide, fun d => by cases d <;> decide, by decide⟩,
    by decide +kernel⟩

/-- **The twin of `col < s`**: on `launch2 2 2 2 2` with stride 1, thread 1 (row 1, column 0) and
thread 2 (row 0, column 1) have one cell, `row * 1 + col = 1`, so `Launch.cell_inj` needs the
columns below the stride. -/
theorem twin_stride : (launch2 2 2 2 2).index 1 .x = 1 ∧ (launch2 2 2 2 2).index 1 .y = 0 ∧
    (launch2 2 2 2 2).index 2 .x = 0 ∧ (launch2 2 2 2 2).index 2 .y = 1 ∧
    (launch2 2 2 2 2).index 1 .x * 1 + (launch2 2 2 2 2).index 1 .y =
      (launch2 2 2 2 2).index 2 .x * 1 + (launch2 2 2 2 2).index 2 .y := by
  decide +kernel

/-- **The instance of `Launch.cell_onto`**: on `launch2 2 2 2 2`, every cell `(r, c)` with `r < 4`
and `c < 4` is the row and column of some thread below 16. -/
theorem onto2222 {r c : Nat} (hr : r < 4) (hc : c < 4) :
    ∃ n < 16, (launch2 2 2 2 2).index n .x = r ∧ (launch2 2 2 2 2).index n .y = c :=
  Launch.cell_onto (L := launch2 2 2 2 2) (launch2_valid (by decide)) hr hc

/-- On `launch2 2 2 2 2`, cell `(3, 2)` is thread 13's (`3 · 4 + 1`: block 3, at block point
`(1, 1, 0)`, and thread 1 of it, at thread point `(1, 0, 0)`, the thread `Launch.index_onto`'s proof
builds), by `decide`. -/
theorem cell32 : (launch2 2 2 2 2).index 13 .x = 3 ∧ (launch2 2 2 2 2).index 13 .y = 2 := by decide

/-- **The twin of the bounds of `Launch.cell_onto`**: no thread of `launch2 2 2 2 2`, below 16 or
not, has row 4 or column 4 (`Launch.index_lt_mul`: rows and columns are below `2 · 2`). -/
theorem twin_onto (n : Nat) : (launch2 2 2 2 2).index n .x ≠ 4 ∧ (launch2 2 2 2 2).index n .y ≠ 4 :=
  ⟨Nat.ne_of_lt (Launch.index_lt_mul (L := launch2 2 2 2 2) (by decide) (by decide) n),
    Nat.ne_of_lt (Launch.index_lt_mul (L := launch2 2 2 2 2) (by decide) (by decide) n)⟩

end MojoProofTest.Index
