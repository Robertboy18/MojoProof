import MojoProof.Sem.Spec

/-!
# The global thread index

The index a 1-D kernel computes, `ctaid.x * ntid.x + tid.x`, as the IR computes it in i64: the
special registers are i32 words, `tid.x` and `ctaid.x` are zero-extended and `ntid.x`
sign-extended to i64, then `mul` and `add`, with any flags (`nuw`, `nsw`). docs/proofs/index.md
has the informal argument. Proved here:

- the operations on words of natural numbers, for every width and all flags: `trunc` and `zext`
  of the word of `k < 2 ^ w` are the word of `k` (`intCast_ofNat`); `sext` of it is too if
  `2 k < 2 ^ w` (`intCast_sext_ofNat`), since its sign bit is clear (`BitVec.toInt_ofNat_of_lt`,
  `outS_of_lt`); `add` and `mul` of the words of `a` and `b` are the word of `a + b` and `a * b`
  when twice the result is below `2 ^ w`, and, for `mul`, twice each operand
  (`intBin_add_ofNat`, `intBin_mul_ofNat`): neither `nuw` nor `nsw` makes them poison. So `trunc`
  to `w'` and then `sext` back of the word of `k` with `2 k < 2 ^ w'` is the word of `k`
  (`intCast_trunc_sext`; the vector kernel's `%22`, `%23` with `w' = 32`).
- `Launch.index_ops`, for every valid launch (`Launch.Valid`), thread number and dimension, and
  all flags: each of the five operations on the special registers' words gives the word of its
  natural-number result, so the IR's index is the i64 word of
  `ctaid d * ntid d + tid d`, which is below `2 ^ 42` (`Launch.index_lt`).
- `Launch.index_oneDim`, for every launch whose grid and block have size 1 in `y` and `z`, and
  every thread number below the launch's thread count: `ctaid.x * ntid.x + tid.x` is the thread
  number.
- `Launch.index_inj`, for every valid launch, two thread numbers and a dimension: equal i64 words
  of the index give equal `ctaid` and equal `tid` in that dimension (as `tid d < ntid d`).

The instance (grid (2, 1, 1), block (4, 1, 1)) and the twin (a 2-D block, on which the index is
not the thread number and not injective) are in MojoProofTest/Index.lean.
-/

namespace MojoProof.Sem

open LLVM

/-- The word of `k` has `k` as its signed value when `2 k < 2 ^ w` (its sign bit is clear), for
every width. -/
theorem _root_.BitVec.toInt_ofNat_of_lt {w k : Nat} (hk : 2 * k < 2 ^ w) :
    (BitVec.ofNat w k).toInt = k := by
  rw [BitVec.toInt_eq_toNat_cond, BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega)]
  simp [hk]

/-- The natural number `k` with `2 k < 2 ^ w` is in the signed range of `w` bits, for every
width. -/
theorem outS_of_lt {w k : Nat} (hk : 2 * k < 2 ^ w) : outS w k = false := by
  unfold outS
  rcases w with _ | w
  · simp at hk
    simp [hk]
  · rw [Nat.pow_succ] at hk
    zify at hk
    simp only [Nat.add_sub_cancel, Bool.not_eq_false', decide_eq_true_eq]
    constructor <;> omega

/-- `trunc` and `zext` to `w'` bits of the word of `k < 2 ^ w` give the word of `k`, for every
pair of widths. -/
theorem intCast_ofNat {op : CastOp} (hop : op = .trunc ∨ op = .zext) {w k : Nat} (w' : Nat)
    (hk : k < 2 ^ w) :
    intCast op w' (.bits w (BitVec.ofNat w k)) = .ok (.bits w' (BitVec.ofNat w' k)) := by
  have e : (BitVec.ofNat w k).setWidth w' = BitVec.ofNat w' k := by
    apply BitVec.eq_of_toNat_eq
    simp [BitVec.toNat_setWidth, Nat.mod_eq_of_lt hk]
  rcases hop with rfl | rfl <;> simp only [intCast, e] <;> rfl

/-- `sext` to `w'` bits of the word of `k` with `2 k < 2 ^ w` gives the word of `k`, for every
pair of widths: the sign bit is clear. -/
theorem intCast_sext_ofNat {w k : Nat} (w' : Nat) (hk : 2 * k < 2 ^ w) :
    intCast .sext w' (.bits w (BitVec.ofNat w k)) = .ok (.bits w' (BitVec.ofNat w' k)) := by
  have hk' : k < 2 ^ w := by omega
  have e : (BitVec.ofNat w k).signExtend w' = BitVec.ofNat w' k := by
    rw [BitVec.signExtend_eq_setWidth_of_msb_false]
    · apply BitVec.eq_of_toNat_eq
      simp [BitVec.toNat_setWidth, Nat.mod_eq_of_lt hk']
    · rw [BitVec.msb_eq_decide, BitVec.toNat_ofNat, Nat.mod_eq_of_lt hk']
      rcases w with _ | w
      · simpa using hk'
      · simp only [Nat.add_sub_cancel, decide_eq_false_iff_not, not_le]
        rw [Nat.pow_succ] at hk
        omega
  simp only [intCast, e]
  rfl

/-- **`trunc`, then `sext` back, is the identity on small words.** For widths `w' ≤ w` and `k`
with `2 k < 2 ^ w'`, `trunc` to `w'` of the word of `k` is the word of `k`, and `sext` of that
back to `w` is the word of `k`. -/
theorem intCast_trunc_sext {w w' k : Nat} (hw : w' ≤ w) (hk : 2 * k < 2 ^ w') :
    intCast .trunc w' (.bits w (BitVec.ofNat w k)) = .ok (.bits w' (BitVec.ofNat w' k)) ∧
      intCast .sext w (.bits w' (BitVec.ofNat w' k)) = .ok (.bits w (BitVec.ofNat w k)) :=
  ⟨intCast_ofNat (.inl rfl) w' (by
    have := Nat.pow_le_pow_right (by omega : 0 < 2) hw
    omega), intCast_sext_ofNat w hk⟩

/-- `add` of the words of `a` and `b` with `2 (a + b) < 2 ^ w` is the word of `a + b`, for every
width and all flags: neither `nuw` nor `nsw` makes it poison. -/
theorem intBin_add_ofNat {w a b : Nat} (fl : IntFlags) (h : 2 * (a + b) < 2 ^ w) :
    intBin w .add fl (.bits w (BitVec.ofNat w a)) (.bits w (BitVec.ofNat w b)) =
      .ok (.bits w (BitVec.ofNat w (a + b))) := by
  have ha : 2 * a < 2 ^ w := by omega
  have hb : 2 * b < 2 ^ w := by omega
  have h1 : decide ((BitVec.ofNat w a).toNat + (BitVec.ofNat w b).toNat ≥ 2 ^ w) = false := by
    simp only [BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega : a < 2 ^ w),
      Nat.mod_eq_of_lt (by omega : b < 2 ^ w), decide_eq_false_iff_not]
    omega
  have h2 := outS_of_lt h
  push_cast at h2
  simp only [intBin, and_self, dite_true, BitVec.cast_eq, intBits, BitVec.toInt_ofNat_of_lt ha,
    BitVec.toInt_ofNat_of_lt hb, h1, h2, Bool.and_false, Bool.or_false, BitVec.ofNat_add_ofNat]
  rfl

/-- `mul` of the words of `a` and `b` with `2 a`, `2 b` and `2 a b` below `2 ^ w` is the word of
`a b`, for every width and all flags: neither `nuw` nor `nsw` makes it poison. -/
theorem intBin_mul_ofNat {w a b : Nat} (fl : IntFlags) (ha : 2 * a < 2 ^ w) (hb : 2 * b < 2 ^ w)
    (h : 2 * (a * b) < 2 ^ w) :
    intBin w .mul fl (.bits w (BitVec.ofNat w a)) (.bits w (BitVec.ofNat w b)) =
      .ok (.bits w (BitVec.ofNat w (a * b))) := by
  have h1 : decide ((BitVec.ofNat w a).toNat * (BitVec.ofNat w b).toNat ≥ 2 ^ w) = false := by
    simp only [BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega : a < 2 ^ w),
      Nat.mod_eq_of_lt (by omega : b < 2 ^ w), decide_eq_false_iff_not]
    omega
  have h2 := outS_of_lt h
  push_cast at h2
  simp only [intBin, and_self, dite_true, BitVec.cast_eq, intBits, BitVec.toInt_ofNat_of_lt ha,
    BitVec.toInt_ofNat_of_lt hb, h1, h2, Bool.and_false, Bool.or_false, BitVec.ofNat_mul_ofNat]
  rfl

/-- The bounds of the special registers on a valid launch, for every thread number and
dimension: `tid d < 1024`, `ctaid d < 2 ^ 31` and `ntid d ≤ 1024`. -/
theorem Launch.sreg_lt {L : Launch} (h : L.Valid) (n : Nat) (d : Dim) :
    (L.env n).sreg .tid d < 1024 ∧ (L.env n).sreg .ctaid d < 2 ^ 31 ∧
      (L.env n).sreg .ntid d ≤ 1024 := by
  have hb : Launch.maxBlock d ≤ 1024 := by cases d <;> decide
  have hg : Launch.maxGrid d < 2 ^ 31 := by cases d <;> decide
  have t := (Launch.sreg_bound h n .tid d).2
  have c := (Launch.sreg_bound h n .ctaid d).2
  have k := (Launch.sreg_bound h n .ntid d).2
  simp only [SReg.hi] at t c k
  omega

/-- On a valid launch, for every thread number and dimension, `ctaid d * ntid d + tid d` is below
`2 ^ 42`. -/
theorem Launch.index_lt {L : Launch} (h : L.Valid) (n : Nat) (d : Dim) :
    (L.env n).sreg .ctaid d * (L.env n).sreg .ntid d + (L.env n).sreg .tid d < 2 ^ 42 := by
  obtain ⟨t, c, k⟩ := Launch.sreg_lt h n d
  have := Nat.mul_le_mul (Nat.le_of_lt c) k
  omega

/-- **The IR's index on words.** For every valid launch, thread number `n`, dimension `d`
and all flags `fl`, `fl'`: `zext` to i64 of the i32 words of `tid d` and `ctaid d`, `sext` of
that of `ntid d`, their `mul` and then the `add` of `tid d` give the i64 words of the natural
numbers, ending in that of `ctaid d * ntid d + tid d`. -/
theorem Launch.index_ops {L : Launch} (h : L.Valid) (n : Nat) (d : Dim) (fl fl' : IntFlags) :
    intCast .zext 64 (.bits 32 (BitVec.ofNat 32 ((L.env n).sreg .tid d))) =
        .ok (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .tid d))) ∧
      intCast .zext 64 (.bits 32 (BitVec.ofNat 32 ((L.env n).sreg .ctaid d))) =
        .ok (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ctaid d))) ∧
      intCast .sext 64 (.bits 32 (BitVec.ofNat 32 ((L.env n).sreg .ntid d))) =
        .ok (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ntid d))) ∧
      intBin 64 .mul fl (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ctaid d)))
          (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ntid d))) =
        .ok (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ctaid d * (L.env n).sreg .ntid d))) ∧
      intBin 64 .add fl'
          (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ctaid d * (L.env n).sreg .ntid d)))
          (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .tid d))) =
        .ok (.bits 64 (BitVec.ofNat 64
          ((L.env n).sreg .ctaid d * (L.env n).sreg .ntid d + (L.env n).sreg .tid d))) := by
  obtain ⟨t, c, k⟩ := Launch.sreg_lt h n d
  have hi := Launch.index_lt h n d
  exact ⟨intCast_ofNat (.inr rfl) 64 (by omega), intCast_ofNat (.inr rfl) 64 (by omega),
    intCast_sext_ofNat 64 (by omega), intBin_mul_ofNat fl (by omega) (by omega) (by omega),
    intBin_add_ofNat fl' (by omega)⟩

/-- **On a 1-D launch the index is the thread number.** For every launch whose grid and
block have size 1 in `y` and `z`, and every thread number `n` below the launch's thread count
`volume L.grid * volume L.block`: `ctaid.x * ntid.x + tid.x` of thread `n` is `n`. -/
theorem Launch.index_oneDim {L : Launch} (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {n : Nat}
    (hn : n < volume L.grid * volume L.block) :
    (L.env n).sreg .ctaid .x * (L.env n).sreg .ntid .x + (L.env n).sreg .tid .x = n := by
  simp only [Launch.env, coord, volume, hg.1, hg.2, hb.1, hb.2, Nat.mul_one] at hn ⊢
  have hB : 0 < L.block .x := Nat.pos_of_ne_zero fun h0 => by simp [h0] at hn
  rw [Nat.mod_mod, Nat.mod_eq_of_lt ((Nat.div_lt_iff_lt_mul hB).2 hn)]
  exact Nat.div_add_mod' n _

/-- **The index is injective in its coordinates.** For every valid launch, thread numbers `n`,
`n'` and dimension `d`: if the i64 words of `ctaid d * ntid d + tid d` of the two threads are
equal, the threads have the same `ctaid d` and the same `tid d`, as `tid d < ntid d` and the
index is below `2 ^ 64` (`Launch.index_lt`). -/
theorem Launch.index_inj {L : Launch} (h : L.Valid) {n n' : Nat} (d : Dim)
    (he : BitVec.ofNat 64
        ((L.env n).sreg .ctaid d * (L.env n).sreg .ntid d + (L.env n).sreg .tid d) =
      BitVec.ofNat 64
        ((L.env n').sreg .ctaid d * (L.env n').sreg .ntid d + (L.env n').sreg .tid d)) :
    (L.env n).sreg .ctaid d = (L.env n').sreg .ctaid d ∧
      (L.env n).sreg .tid d = (L.env n').sreg .tid d := by
  have e := congrArg BitVec.toNat he
  rw [BitVec.toNat_ofNat, BitVec.toNat_ofNat,
    Nat.mod_eq_of_lt (by have := Launch.index_lt h n d; omega),
    Nat.mod_eq_of_lt (by have := Launch.index_lt h n' d; omega)] at e
  have hB := h.block_pos d
  have t : (L.env n).sreg .tid d < L.block d := coord_lt _ hB
  have t' : (L.env n').sreg .tid d < L.block d := coord_lt _ hB
  simp only [show ∀ m, (L.env m).sreg .ntid d = L.block d from fun _ => rfl] at e
  have hc : (L.env n).sreg .ctaid d = (L.env n').sreg .ctaid d := by
    have := congrArg (· / L.block d) e
    simp only [Nat.mul_add_div hB, Nat.div_eq_of_lt t, Nat.div_eq_of_lt t', Nat.add_zero,
      Nat.mul_comm _ (L.block d)] at this
    exact this
  refine ⟨hc, ?_⟩
  rw [hc, Nat.mul_comm] at e
  omega

end MojoProof.Sem
