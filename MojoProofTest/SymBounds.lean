import MojoProof.Sym.Bounds
import MojoProof.Sem.Index

/-!
# The tactic mojo_bounds on `vector_addition`'s index arithmetic (MojoProof/Sym/Bounds.lean)

The index of `vector_addition` (tests/corpus/vadd/…nvptx.ll:14-28) is
`%19 = zext ctaid.x * sext ntid.x + zext tid.x` in 64 bits, compared by `icmp slt` with the
sign-extended element count `%11 = sext %3`, then truncated to 32 bits and sign-extended back
(`%22`, `%23`). The special registers' `range` attributes (`…nvptx.ll:46-52`) give
`tid.x < 1024`, `ctaid.x < 2147483647` and `1 ≤ ntid.x < 1025`.

* `vadd_index`: under those ranges and `%19 <s %11`, the truncation then sign extension is the
  identity on `%19`'s signed value, and that value is in `[0, n)`.
* `vadd_index_launch`: the same for the special registers of every thread of every valid launch
  (`Launch.Valid`, whose registers lie in the ranges by `Launch.sreg_bound`).
* `vadd_index_1d`: on every valid launch whose grid and block have side 1 in `y` and `z`, thread
  `i`'s index `%19` has signed value `i` and the branch condition `%19 <s %11` is `i < n`
  (`Launch.index_oneDim`, MojoProof/Sem/Index.lean); `vadd_index_1d_twin`: on a block of 1 × 2
  threads, thread 1's index is 0, so the side-1 premise is needed.
* `vadd_access`: the access of `getelementptr inbounds float` at that index into a buffer of at
  least `4 * n` bytes, from offset 0, is in bounds: `0 ≤ off ∧ off + 4 ≤ len` with
  `off = Int.bmod (0 + 4 * i) (2 ^ 64)`, the offset `gepPtr` computes.
* `rem_var`: a remainder by a variable `k` of a value below `2 ^ 32`, truncated to 32 bits, is
  unchanged (the bound of a remainder by its dividend's bound).
* `vadd_access_open`: without the path condition `%19 <s %11` (here hidden in a definition that
  the tactic does not unfold), the tactic leaves two goals open, one per sign of `n`,
  lowered: the index (`ctaid.x * ntid.x + tid.x`, its remainders gone by their bounds) below `n`'s
  signed value. `#guard_msgs` checks the two messages; unfolding the definition then closes both.

Each result is for every value of the registers, the element count and the other variables
meeting the hypotheses.
-/

namespace MojoProofTest.SymBounds

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

/-- The index `%19` of `vector_addition` from `ctaid.x`, `ntid.x` and `tid.x`. -/
abbrev idx (a b c : BitVec 32) : BitVec 64 := a.setWidth 64 * b.signExtend 64 + c.setWidth 64

/-- **The index**: under the ranges of the special registers and the path condition, `trunc`
then `sext` gives back the index, which lies in `[0, n)`. -/
theorem vadd_index (a b c n : BitVec 32) (ha : a.toNat < 2147483647) (hb₁ : 1 ≤ b.toNat)
    (hb₂ : b.toNat < 1025) (hc : c.toNat < 1024) (hlt : (idx a b c).slt (n.signExtend 64) = true) :
    (((idx a b c).setWidth 32).signExtend 64).toInt = (idx a b c).toInt ∧
      0 ≤ (idx a b c).toInt ∧ (idx a b c).toInt < n.toInt := by
  refine ⟨?_, ?_, ?_⟩ <;> mojo_bounds

/-- Special register `r` in dimension `x` of thread number `i` of launch `L` as the 32-bit word a
call of it gives (`SNode.eval`). -/
abbrev sreg (L : Launch) (i : Nat) (r : SReg) : BitVec 32 := BitVec.ofNat 32 ((L.env i).sreg r .x)

/-- **The index on every thread of every valid launch**: thread `i`'s special registers lie in the
ranges `vadd_index` assumes (`Launch.sreg_bound`), so for every valid launch, every thread and
every element count with the path condition, `trunc` then `sext` gives back the index, which
lies in `[0, n)`. -/
theorem vadd_index_launch {L : Launch} (hL : L.Valid) (i : Nat) (n : BitVec 32)
    (hlt : (idx (sreg L i .ctaid) (sreg L i .ntid) (sreg L i .tid)).slt (n.signExtend 64) = true) :
    let j := idx (sreg L i .ctaid) (sreg L i .ntid) (sreg L i .tid)
    ((j.setWidth 32).signExtend 64).toInt = j.toInt ∧ 0 ≤ j.toInt ∧ j.toInt < n.toInt := by
  obtain ⟨-, ha⟩ := L.sreg_bound hL i .ctaid .x
  obtain ⟨hb₁, hb₂⟩ := L.sreg_bound hL i .ntid .x
  obtain ⟨-, hc⟩ := L.sreg_bound hL i .tid .x
  simp only [SReg.lo, SReg.hi, Launch.maxGrid, Launch.maxBlock] at ha hb₁ hb₂ hc
  exact vadd_index _ _ _ _ (by mojo_bounds) (by mojo_bounds) (by mojo_bounds) (by mojo_bounds) hlt

/-- **The index on every thread of every valid 1-D launch**: for every valid launch whose grid
and block have side 1 in `y` and `z`, every thread number `i` below the number of threads and
every element count `n`, the index has signed value `i` (`Launch.index_oneDim`) and the path
condition holds exactly when `i < n`. -/
theorem vadd_index_1d {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {i : Nat} (hi : i < volume L.grid * volume L.block)
    (n : BitVec 32) :
    (idx (sreg L i .ctaid) (sreg L i .ntid) (sreg L i .tid)).toInt = i ∧
      ((idx (sreg L i .ctaid) (sreg L i .ntid) (sreg L i .tid)).slt (n.signExtend 64) = true ↔
        (i : Int) < n.toInt) := by
  obtain ⟨-, ha⟩ := L.sreg_bound hL i .ctaid .x
  obtain ⟨hb₁, hb₂⟩ := L.sreg_bound hL i .ntid .x
  obtain ⟨-, hc⟩ := L.sreg_bound hL i .tid .x
  simp only [SReg.lo, SReg.hi, Launch.maxGrid, Launch.maxBlock] at ha hb₁ hb₂ hc
  have e := Launch.index_oneDim hg hb hi
  clear hi
  constructor <;> mojo_bounds

/-- **The twin**: on the launch of one block of 1 × 2 threads (side 2 in `y`), thread 1 has
`tid.x = 0`, so its index is 0, not 1. -/
theorem vadd_index_1d_twin :
    let L := launch2 1 1 1 2
    (idx (sreg L 1 .ctaid) (sreg L 1 .ntid) (sreg L 1 .tid)).toInt = 0 := by
  decide

/-- **The access**: the element at the index of a buffer of at least `4 * n` bytes from offset 0
is in bounds, as `Mem.check` asks. -/
theorem vadd_access (a b c n : BitVec 32) (len : Int) (ha : a.toNat < 2147483647)
    (hb₁ : 1 ≤ b.toNat) (hb₂ : b.toNat < 1025) (hc : c.toNat < 1024)
    (hlt : (idx a b c).slt (n.signExtend 64) = true) (hlen : 4 * n.toInt ≤ len) :
    0 ≤ Int.bmod (0 + 4 * (((idx a b c).setWidth 32).signExtend 64).toInt) (2 ^ 64) ∧
      Int.bmod (0 + 4 * (((idx a b c).setWidth 32).signExtend 64).toInt) (2 ^ 64) + 4 ≤ len := by
  constructor <;> mojo_bounds

/-- **A remainder by a variable**: for every `x < 2 ^ 32` and every `k`, the remainder `x % k`
taken again modulo `2 ^ 32` (a `trunc` to 32 bits) is unchanged; its bound is the dividend's
(core's `Nat.mod_lt_of_lt`), since the modulus `k` has no value. -/
theorem rem_var (x k : Nat) (hx : x < 2 ^ 32) : x % k % 2 ^ 32 = x % k := by
  mojo_bounds

/-- The path condition, behind a definition. -/
def Below (a b c n : BitVec 32) : Prop := (idx a b c).slt (n.signExtend 64) = true

/--
info: mojo_bounds: open goal
  ↑(a.toNat * b.toNat + c.toNat) < ↑n.toNat
---
info: mojo_bounds: open goal
  ↑(a.toNat * b.toNat + c.toNat) < ↑n.toNat - ↑(2 ^ 32)
-/
#guard_msgs in
/-- **The open goal**: with the path condition behind `Below`, `mojo_bounds` leaves the lowered
goals open, one per sign of `n`; unfolding `Below` and `mojo_bounds` again close them. -/
theorem vadd_access_open (a b c n : BitVec 32) (ha : a.toNat < 2147483647) (hb₁ : 1 ≤ b.toNat)
    (hb₂ : b.toNat < 1025) (hc : c.toNat < 1024) (hlt : Below a b c n) :
    (idx a b c).toInt < n.toInt := by
  mojo_bounds
  all_goals (unfold Below at hlt; mojo_bounds)

end MojoProofTest.SymBounds
