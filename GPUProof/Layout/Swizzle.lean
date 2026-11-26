import GPUProof.Layout.Algebra

/-!
# The laws of the swizzle

The laws of docs/proofs/layout-laws.md about Mojo's XOR swizzle (`Swizzle`, swizzle.mojo), for
every value, base and shift:

* `Swizzle.call_call`: when the number of bits is at most the absolute shift (the constructor's
  check), the swizzle is its own inverse, hence a bijection;
* `Swizzle.call_xor`: the swizzle is linear over the two-element field, for every swizzle.
-/

namespace GPUProof.Layout

/-- `shiftr` distributes over XOR, for every shift, positive or not. -/
theorem shiftr_xor (a b : Nat) (s : Int) : shiftr (a ^^^ b) s = shiftr a s ^^^ shiftr b s := by
  unfold shiftr
  split <;> simp [Nat.shiftRight_xor_distrib, Nat.shiftLeft_xor_distrib]

/-- When the number of bits is at most the absolute shift, the shifted source bits miss the
source mask: `shiftr(x & yyy_mask, shift) & yyy_mask = 0`, for every value, base and shift. -/
theorem Swizzle.shiftr_and_mask (S : Swizzle) (h : S.bits ≤ S.shift.natAbs) (x : Nat) :
    shiftr (x &&& S.mask) S.shift &&& S.mask = 0 := by
  apply Nat.eq_of_testBit_eq
  intro i
  simp only [Nat.zero_testBit, Nat.testBit_and, Swizzle.mask, shiftr]
  split
  · simp only [Nat.testBit_shiftRight, Nat.testBit_and, Nat.testBit_shiftLeft,
      Nat.testBit_two_pow_sub_one]
    cases x.testBit (S.shift.toNat + i) <;> simp <;> omega
  · simp only [Nat.testBit_shiftLeft, Nat.testBit_and, Nat.testBit_two_pow_sub_one]
    cases x.testBit (i - (-S.shift).toNat) <;> simp <;> omega

/-- **The swizzle is an involution** (swizzle card): when `bits ≤ |shift|`, the check Mojo's
constructor makes (swizzle.mojo:332), applying the swizzle twice gives the value back, so the
swizzle is a bijection. For every value, base and shift, positive or negative. -/
theorem Swizzle.call_call (S : Swizzle) (h : S.bits ≤ S.shift.natAbs) (x : Nat) :
    S.call (S.call x) = x := by
  have e : S.call x &&& S.mask = x &&& S.mask := by
    rw [Swizzle.call, Nat.and_xor_distrib_right, S.shiftr_and_mask h x, Nat.xor_zero]
  show S.call x ^^^ shiftr (S.call x &&& S.mask) S.shift = x
  rw [e, Swizzle.call, Nat.xor_assoc, Nat.xor_self, Nat.xor_zero]

/-- **The swizzle is linear over F2** (bit-layout card): `S(x ^ y) = S(x) ^ S(y)`. For every
swizzle and every pair of values, with no premise on the bits or the shift. -/
theorem Swizzle.call_xor (S : Swizzle) (x y : Nat) :
    S.call (x ^^^ y) = S.call x ^^^ S.call y := by
  simp only [Swizzle.call, Nat.and_xor_distrib_right, shiftr_xor]
  generalize shiftr (x &&& S.mask) S.shift = a
  generalize shiftr (y &&& S.mask) S.shift = c
  apply Nat.eq_of_testBit_eq
  intro i
  simp only [Nat.testBit_xor]
  cases x.testBit i <;> cases y.testBit i <;> cases a.testBit i <;> cases c.testBit i <;> rfl

end GPUProof.Layout
