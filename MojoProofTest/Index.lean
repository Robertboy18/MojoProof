import MojoProof.Sem.Index

/-!
# Instance and twin of the global thread index

The instance, one launch: grid (2, 1, 1) and block (4, 1, 1) (`L24`), valid (`valid24`). By the
library theorems, for each of its 8 threads the IR's operations on the special registers' words
give the i64 word of the thread number (`index24`: `Launch.index_ops` and `Launch.index_oneDim`),
and so does the evaluation of the same five operations (`eval24`, by `decide`). Two threads with
equal index words are one thread (`inj24`, `Launch.index_inj`). For each index below 8, `trunc` to
i32 and `sext` back give its i64 word (`roundtrip24`, `intCast_trunc_sext`); at `2 ^ 31` they do
not (`roundtrip_twin`).

The twin, one launch: grid (1, 1, 1) and block (2, 2, 1) (`L22`, valid), a 2-D block. Thread 2
has `tid` (0, 1), so its `ctaid.x * ntid.x + tid.x` is 0, not 2, and is that of thread 0
(`twin22`): `Launch.index_oneDim` needs its premise on the block, and on this launch the index is
not injective on thread numbers, though `Launch.index_inj` still gives equal `ctaid.x` and
`tid.x`.
-/

namespace MojoProofTest.Index

open MojoProof.Sem MojoProof.LLVM

/-- The launch of grid (2, 1, 1) and block (4, 1, 1). -/
def L24 : Launch := ⟨fun | .x => 2 | _ => 1, fun | .x => 4 | _ => 1, 0⟩

/-- `L24` is valid. -/
theorem valid24 : L24.Valid where
  grid_pos d := by cases d <;> decide
  grid_le d := by cases d <;> decide
  block_pos d := by cases d <;> decide
  block_le d := by cases d <;> decide
  threads := by decide

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

/-- **The instance, by the library theorems**: for each thread `n < 8` of `L24` and all flags
`fl` (of the `mul`) and `fl'` (of the `add`), the five operations (`zext` of the i32 words of
`tid.x` and `ctaid.x`, `sext` of that of `ntid.x`, their `mul`, then the `add` of `tid.x`) give the
i64 word of `n` (`Launch.index_ops`, `Launch.index_oneDim`). -/
theorem index24 (fl fl' : IntFlags) {n : Nat} (hn : n < 8) :
    (do
      let t ← intCast .zext 64 (.bits 32 (BitVec.ofNat 32 ((L24.env n).sreg .tid .x)))
      let b ← intCast .zext 64 (.bits 32 (BitVec.ofNat 32 ((L24.env n).sreg .ctaid .x)))
      let k ← intCast .sext 64 (.bits 32 (BitVec.ofNat 32 ((L24.env n).sreg .ntid .x)))
      let p ← intBin 64 .mul fl b k
      intBin 64 .add fl' p t : Except Fault Val) = .ok (.bits 64 (BitVec.ofNat 64 n)) := by
  obtain ⟨h1, h2, h3, h4, h5⟩ := Launch.index_ops valid24 n .x fl fl'
  rw [Launch.index_oneDim ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by simpa [volume, L24] using hn)] at h5
  simp only [h1, h2, h3, h4, h5, bind, Except.bind]

/-- **The instance, by evaluation**: for each thread `n < 8` of `L24` the five operations give
the i64 word of `n`. -/
theorem eval24 : (List.range 8).all (fun n => evalIndex L24 n == some (BitVec.ofNat 64 n)) =
    true := by
  decide +kernel

/-- The instance of `Launch.index_inj`: on `L24`, threads below 8 with equal index words are one
thread. -/
theorem inj24 {n n' : Nat} (hn : n < 8) (hn' : n' < 8)
    (he : BitVec.ofNat 64
        ((L24.env n).sreg .ctaid .x * (L24.env n).sreg .ntid .x + (L24.env n).sreg .tid .x) =
      BitVec.ofNat 64
        ((L24.env n').sreg .ctaid .x * (L24.env n').sreg .ntid .x + (L24.env n').sreg .tid .x)) :
    n = n' := by
  obtain ⟨hc, ht⟩ := Launch.index_inj valid24 .x he
  have e := Launch.index_oneDim (L := L24) ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (n := n)
    (by simpa [volume, L24] using hn)
  have e' := Launch.index_oneDim (L := L24) ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (n := n')
    (by simpa [volume, L24] using hn')
  rw [hc, ht] at e
  exact e.symm.trans e'

/-- The instance of `intCast_trunc_sext` (the vector kernel's `%22`, `%23`): for each index
`n < 8` of `L24`, `trunc` to i32 and `sext` back give the i64 word of `n`. -/
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

/-- The launch of grid (1, 1, 1) and block (2, 2, 1). -/
def L22 : Launch := ⟨fun _ => 1, fun | .z => 1 | _ => 2, 0⟩

/-- **The twin**: `L22` is valid and has 4 threads, but thread 2's `ctaid.x * ntid.x + tid.x` is
0, that of thread 0, so on a 2-D block the index is not the thread number and not injective on
thread numbers; its `ctaid.x` and `tid.x` are those of thread 0, as `Launch.index_inj` says. -/
theorem twin22 : L22.Valid ∧ volume L22.grid * volume L22.block = 4 ∧
    (L22.env 2).sreg .ctaid .x * (L22.env 2).sreg .ntid .x + (L22.env 2).sreg .tid .x = 0 ∧
    (L22.env 0).sreg .ctaid .x * (L22.env 0).sreg .ntid .x + (L22.env 0).sreg .tid .x = 0 ∧
    (L22.env 2).sreg .tid .y = 1 ∧ evalIndex L22 2 = some 0 :=
  ⟨⟨fun d => by cases d <;> decide, fun d => by cases d <;> decide,
    fun d => by cases d <;> decide, fun d => by cases d <;> decide, by decide⟩,
    rfl, rfl, rfl, rfl, by decide +kernel⟩

end MojoProofTest.Index
