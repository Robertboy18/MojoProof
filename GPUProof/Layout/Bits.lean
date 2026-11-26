import GPUProof.Layout.Laws

/-!
# Bit layouts

`BitLayout` of max/kernels/src/layout/bit_layout.mojo at modular/modular bbc13a71, a map over F2
from domain bits to codomain points, with its test of bit-linearity (`isBitLinear`) and
`placement` on flat static layouts, transcribed over the model of GPUProof/Layout/Basic.lean,
and its laws, for every input that meets each law's premises. The model computes on natural
numbers where Mojo computes on `UInt64`, which drops the bits from 64 on; the two agree while
every image, span and offset lies below `2 ^ 64`.

* `BitLayout.call_xor`: every bit layout is linear over F2, `m(x ^ y) = m(x) ^ m(y)`;
* `placement_call`: on a flat layout that `isBitLinear` accepts, the placement's domain mask is
  the size minus 1, and its value at every point below the size is the layout's offset of that
  point.
-/

namespace GPUProof.Layout

open Tup

/-! ## The transcription -/

/-- `BitLayout` (bit_layout.mojo:66-82): a map over F2 whose domain bit `i` goes to the codomain
point `img i`, where `dom` is the mask of the domain bits the map has. Mojo keeps 64 images
(`BIT_LAYOUT_BITS`, line 34) in a `SIMD` vector and its masks in `UInt64`s; the model's images
are a function and its mask a natural number. Mojo's third field `dead`, which `kill` sets and
`__call__` does not read, is not modelled; on `__call__`, `kill d` acts as `put d 0`. -/
structure BitLayout where
  /-- The bit layout whose domain bit `i` goes to `img i`, with the domain mask `dom`. -/
  mk ::
  /-- The image of each domain bit. -/
  img : Nat → Nat
  /-- The mask of the domain bits the map has. -/
  dom : Nat

/-- `BitLayout()` (bit_layout.mojo:84-88): the empty map. -/
def BitLayout.empty : BitLayout := ⟨fun _ => 0, 0⟩

/-- `BitLayout.put` (bit_layout.mojo:90-104): domain bit `d` goes to `image`, and `dom` gains
the bit `bit(d) = 1 << d`. -/
def BitLayout.put (m : BitLayout) (d image : Nat) : BitLayout :=
  ⟨fun i => if i = d then image else m.img i, m.dom ||| 1 <<< d⟩

/-- The XOR of the images `img i`, `img (i + 1)`, ... of the set bits among the `k` lowest bits
of `r`, the lowest bit going to `img i`. -/
def xorBits (img : Nat → Nat) : Nat → Nat → Nat → Nat
  | _, 0, _ => 0
  | i, k + 1, r => (if r % 2 = 1 then img i else 0) ^^^ xorBits img (i + 1) k (r / 2)

/-- `BitLayout.__call__` (bit_layout.mojo:168-182): the XOR of the images of the set bits of
`x & dom`. Mojo visits them lowest first, by `count_trailing_zeros`, among the 64 bits of a
`UInt64`; the model visits the 64 lowest bits in order, and XOR does not depend on the order. -/
def BitLayout.call (m : BitLayout) (x : Nat) : Nat := xorBits m.img 0 64 (x &&& m.dom)

/-- `count_trailing_zeros` on the `f` lowest bits: the number of trailing zero bits of `n`, and
`f` when those bits are all zero. -/
def trailingZeros : Nat → Nat → Nat
  | 0, _ => 0
  | f + 1, n => if n % 2 = 1 then 0 else trailingZeros f (n / 2) + 1

/-- `_log2` (bit_layout.mojo:222-223): `count_trailing_zeros` of the value as a `UInt64`, so the
exponent of a power of two below `2 ^ 64`, and 64 for 0. -/
def log2 (n : Nat) : Nat := trailingZeros 64 n

/-- `_power_of_two` (bit_layout.mojo:226-227): `n > 0` and `n & (n - 1) == 0`. -/
def powerOfTwo (n : Nat) : Bool := 0 < n && n &&& (n - 1) == 0

/-- `bits(lo, n)` (bit_layout.mojo:52-62): the mask of the bits `lo` through `lo + n - 1`,
`((1 << n) - 1) << lo`. -/
def bitsMask (lo n : Nat) : Nat := ((1 <<< n) - 1) <<< lo

/-- The loop of `is_bit_linear` (bit_layout.mojo:245-258) over the (extent, stride) modes of a
flat static layout, from the mask `reached` of the offset bits that earlier modes reach: every
extent is a power of two, and every stride is 0, or a power of two whose span of offset bits
(`bits(log2(stride), log2(extent))`) misses `reached` and joins it. -/
def bitLinear : List (Nat × Nat) → Nat → Bool
  | [], _ => true
  | (e, s) :: ms, r => powerOfTwo e &&
      if s = 0 then bitLinear ms r
      else powerOfTwo s && r &&& bitsMask (log2 s) (log2 e) == 0 &&
        bitLinear ms (r ||| bitsMask (log2 s) (log2 e))

/-- `is_bit_linear` (bit_layout.mojo:230-258) of the flat static layout of the (extent, stride)
modes `ms`: `bitLinear` from the empty mask. A layout with runtime leaves, which Mojo refuses,
and nested modes are not modelled. -/
def isBitLinear (ms : List (Nat × Nat)) : Bool := bitLinear ms 0

/-- The inner loop of `placement` (bit_layout.mojo:280-282): `n` coordinate bits of a mode of
stride `s`, from the coordinate bit `b` on, take the domain bits `d`, `d + 1`, ... and go to
`s << b`, `s << (b + 1)`, .... -/
def placeMode (s : Nat) : Nat → Nat → Nat → BitLayout → BitLayout
  | _, _, 0, m => m
  | d, b, n + 1, m => placeMode s (d + 1) (b + 1) n (m.put d (s <<< b))

/-- The outer loop of `placement` (bit_layout.mojo:277-282): each mode (extent, stride) in order
places its `log2(extent)` coordinate bits from the domain bit `d` on. -/
def placeModes : List (Nat × Nat) → Nat → BitLayout → BitLayout
  | [], _, m => m
  | (e, s) :: ms, d, m => placeModes ms (d + log2 e) (placeMode s d 0 (log2 e) m)

/-- `placement` (bit_layout.mojo:261-283) of the flat static layout of the modes `ms`: the
coordinate bits number the points colexicographically, mode 0's bits lowest, and bit `b` of
mode `i` goes to `stride_i << b`. -/
def placement (ms : List (Nat × Nat)) : BitLayout := placeModes ms 0 BitLayout.empty

/-! ## Linearity -/

/-- `xorBits` of 0 is 0. -/
theorem xorBits_zero (img : Nat → Nat) : ∀ i k, xorBits img i k 0 = 0
  | _, 0 => rfl
  | i, k + 1 => by simp [xorBits, xorBits_zero img (i + 1) k]

/-- `xorBits` is linear over F2. -/
theorem xorBits_xor (img : Nat → Nat) : ∀ i k r s,
    xorBits img i k (r ^^^ s) = xorBits img i k r ^^^ xorBits img i k s
  | _, 0, _, _ => by simp [xorBits]
  | i, k + 1, r, s => by
    simp only [xorBits, Nat.xor_div_two, xorBits_xor img (i + 1) k]
    generalize xorBits img (i + 1) k (r / 2) = X
    generalize xorBits img (i + 1) k (s / 2) = Y
    have e : ∀ c : Prop, [Decidable c] → (if c then img i else 0) =
        if decide c = true then img i else 0 := fun c _ => by simp
    rw [e ((r ^^^ s) % 2 = 1), e (r % 2 = 1), e (s % 2 = 1)]
    have hx : decide ((r ^^^ s) % 2 = 1) = (decide (r % 2 = 1) ^^ decide (s % 2 = 1)) := by
      rcases Nat.mod_two_eq_zero_or_one r with hr | hr <;>
        rcases Nat.mod_two_eq_zero_or_one s with hs | hs <;> simp [hr, hs]
    rw [hx]
    apply Nat.eq_of_testBit_eq
    intro j
    cases decide (r % 2 = 1) <;> cases decide (s % 2 = 1) <;>
      simp only [Nat.testBit_xor, Nat.zero_testBit, Bool.false_xor, Bool.true_xor, Bool.not_true,
        Bool.not_false, Bool.false_eq_true, ↓reduceIte] <;>
      cases (img i).testBit j <;> cases X.testBit j <;> cases Y.testBit j <;> rfl

/-- **A bit layout is linear over F2** (bit-layout card): `m(x ^ y) = m(x) ^ m(y)`, for every
bit layout and every pair of points. -/
theorem BitLayout.call_xor (m : BitLayout) (x y : Nat) :
    m.call (x ^^^ y) = m.call x ^^^ m.call y := by
  simp only [BitLayout.call, Nat.and_xor_distrib_right, xorBits_xor]

/-! ## Placement -/

/-- `xorBits` over `k + k'` bits is the XOR of the `k` low bits' images and the next `k'` bits'
images. -/
theorem xorBits_add (img : Nat → Nat) : ∀ i k k' r,
    xorBits img i (k + k') r = xorBits img i k r ^^^ xorBits img (i + k) k' (r / 2 ^ k)
  | i, 0, k', r => by simp [xorBits]
  | i, k + 1, k', r => by
    rw [show k + 1 + k' = (k + k') + 1 by omega]
    simp only [xorBits]
    rw [xorBits_add img (i + 1) k k' (r / 2), Nat.xor_assoc, show i + 1 + k = i + (k + 1) by omega,
      Nat.div_div_eq_div_mul, ← Nat.pow_succ']

/-- `xorBits` over `F ≥ K` bits of an `r` below `2 ^ K` is `xorBits` over `K` bits. -/
theorem xorBits_of_lt (img : Nat → Nat) (i K F r : Nat) (hK : K ≤ F) (hr : r < 2 ^ K) :
    xorBits img i F r = xorBits img i K r := by
  rw [show F = K + (F - K) by omega, xorBits_add, Nat.div_eq_of_lt hr, xorBits_zero, Nat.xor_zero]

/-- XOR of numbers with no common bit is their sum. -/
theorem xor_eq_add (a b : Nat) (h : a &&& b = 0) : a ^^^ b = a + b := by
  induction a using Nat.strongRecOn generalizing b with
  | ind a ih =>
    rcases Nat.eq_zero_or_pos a with rfl | ha
    · simp
    have e1 := ih (a / 2) (by omega) (b / 2) (by rw [← Nat.and_div_two, h])
    have h1 : ¬ (a % 2 = 1 ∧ b % 2 = 1) := by rw [← Nat.and_mod_two_eq_one, h]; decide
    have h2 := Nat.xor_mod_two_eq_one (a := a) (b := b)
    have e := Nat.div_add_mod (a ^^^ b) 2
    rw [Nat.xor_div_two, e1] at e
    have := Nat.div_add_mod a 2
    have := Nat.div_add_mod b 2
    rcases Nat.mod_two_eq_zero_or_one a with hx | hx <;>
      rcases Nat.mod_two_eq_zero_or_one b with hy | hy <;>
      rcases Nat.mod_two_eq_zero_or_one (a ^^^ b) with hz | hz <;>
      rw [hx, hy, hz] at h2 <;> rw [hx, hy] at h1 <;> simp at h1 h2 <;> omega

/-- A number whose bits lie in `S` has no bit in common with `R` when `S` has none. -/
theorem and_eq_zero_of_sub (a S R : Nat) (ha : a &&& S = a) (h : S &&& R = 0) : a &&& R = 0 := by
  apply Nat.eq_of_testBit_eq
  intro j
  have h1 := congrArg (Nat.testBit · j) ha
  have h2 := congrArg (Nat.testBit · j) h
  simp only [Nat.testBit_and, Nat.zero_testBit] at h1 h2 ⊢
  cases hA : a.testBit j <;> cases hS : S.testBit j <;> cases hR : R.testBit j <;> simp_all

/-- `y mod 2 ^ k` times `2 ^ t` lies in the span `bits(t, k)`. -/
theorem and_bitsMask (y k t : Nat) : y % 2 ^ k * 2 ^ t &&& bitsMask t k = y % 2 ^ k * 2 ^ t := by
  apply Nat.eq_of_testBit_eq
  intro j
  rw [Nat.mul_comm, bitsMask, Nat.one_shiftLeft]
  simp only [Nat.testBit_and, Nat.testBit_two_pow_mul, Nat.testBit_shiftLeft,
    Nat.testBit_two_pow_sub_one, Nat.testBit_mod_two_pow]
  cases decide (j ≥ t) <;> cases decide (j - t < k) <;> simp

/-- On a mode of stride 0 or a power of two `s`, whose `n` coordinate bits go to `s`, `2 s`, ...,
`xorBits` of `y` is `(y mod 2 ^ n) * s`. -/
theorem xorBits_stride (img : Nat → Nat) : ∀ (n i s : Nat), (s = 0 ∨ ∃ t, s = 2 ^ t) →
    (∀ j, j < n → img (i + j) = s * 2 ^ j) → ∀ y, xorBits img i n y = y % 2 ^ n * s
  | 0, _, _, _, _, y => by simp [xorBits, Nat.mod_one]
  | n + 1, i, s, hs, hi, y => by
    have hs2 : 2 * s = 0 ∨ ∃ t, 2 * s = 2 ^ t := by
      rcases hs with rfl | ⟨t, rfl⟩
      · exact Or.inl rfl
      · exact Or.inr ⟨t + 1, by rw [Nat.pow_succ']⟩
    have ih := xorBits_stride img n (i + 1) (2 * s) hs2 (fun j hj => by
      rw [show i + 1 + j = i + (j + 1) by omega, hi (j + 1) (by omega), Nat.pow_succ',
        Nat.mul_left_comm, Nat.mul_assoc]) (y / 2)
    have h0 : img i = s := by simpa using hi 0 (by omega)
    simp only [xorBits, ih, h0]
    rw [Nat.pow_succ', Nat.mod_mul]
    rcases Nat.mod_two_eq_zero_or_one y with hy | hy
    · simp only [hy, Nat.zero_ne_one, ↓reduceIte, Nat.zero_xor]
      simp only [Nat.zero_add, Nat.mul_comm, Nat.mul_assoc]
    · simp only [hy, ↓reduceIte]
      rcases hs with rfl | ⟨t, rfl⟩
      · simp
      rw [xor_eq_add]
      · simp only [Nat.add_mul, Nat.one_mul, Nat.mul_assoc, Nat.mul_left_comm]
      · apply Nat.eq_of_testBit_eq
        intro j
        rw [show y / 2 % 2 ^ n * (2 * 2 ^ t) = 2 ^ (t + 1) * (y / 2 % 2 ^ n) by
          rw [Nat.pow_succ', Nat.mul_comm]]
        simp only [Nat.testBit_and, Nat.testBit_two_pow, Nat.testBit_two_pow_mul,
          Nat.zero_testBit]
        by_cases hj : t = j
        · subst hj; simp <;> omega
        · simp [hj]

/-- `placeMode` leaves the images of the domain bits below `d`. -/
theorem placeMode_img_lt (s : Nat) : ∀ (n d b : Nat) (m : BitLayout) (j : Nat), j < d →
    (placeMode s d b n m).img j = m.img j
  | 0, _, _, _, _, _ => rfl
  | n + 1, d, b, m, j, hj => by
    simp only [placeMode]
    rw [placeMode_img_lt s n (d + 1) (b + 1) _ j (by omega)]
    simp [BitLayout.put, show j ≠ d by omega]

/-- `placeMode` sends its `j`-th domain bit to `s * 2 ^ (b + j)`. -/
theorem placeMode_img (s : Nat) : ∀ (n d b : Nat) (m : BitLayout) (j : Nat), j < n →
    (placeMode s d b n m).img (d + j) = s * 2 ^ (b + j)
  | 0, _, _, _, _, hj => absurd hj (Nat.not_lt_zero _)
  | n + 1, d, b, m, 0, _ => by
    simp only [placeMode]
    rw [placeMode_img_lt s n (d + 1) (b + 1) _ _ (by omega)]
    simp [BitLayout.put, Nat.shiftLeft_eq]
  | n + 1, d, b, m, j + 1, hj => by
    simp only [placeMode]
    rw [show d + (j + 1) = d + 1 + j by omega, placeMode_img s n (d + 1) (b + 1) _ j (by omega),
      show b + 1 + j = b + (j + 1) by omega]

/-- `placeMode` from the mask of the domain bits below `d` gives the mask of those below
`d + n`. -/
theorem placeMode_dom (s : Nat) : ∀ (n d b : Nat) (m : BitLayout), m.dom = 2 ^ d - 1 →
    (placeMode s d b n m).dom = 2 ^ (d + n) - 1
  | 0, _, _, _, h => h
  | n + 1, d, b, m, h => by
    simp only [placeMode]
    rw [placeMode_dom s n (d + 1) (b + 1) _ ?_, show d + 1 + n = d + (n + 1) by omega]
    have hp := Nat.two_pow_pos d
    simp only [BitLayout.put, h, Nat.one_shiftLeft]
    rw [Nat.or_two_pow_eq_add_of_lt (by omega), Nat.pow_succ]
    omega

/-- `placeModes` leaves the images of the domain bits below `d`. -/
theorem placeModes_img_lt : ∀ (ms : List (Nat × Nat)) (d : Nat) (m : BitLayout) (j : Nat),
    j < d → (placeModes ms d m).img j = m.img j
  | [], _, _, _, _ => rfl
  | (e, s) :: ms, d, m, j, hj => by
    simp only [placeModes]
    rw [placeModes_img_lt ms _ _ j (by omega), placeMode_img_lt s _ d 0 m j hj]

/-- `placeModes` from the mask of the domain bits below `d` gives the mask of those below `d`
plus the modes' bits. -/
theorem placeModes_dom : ∀ (ms : List (Nat × Nat)) (d : Nat) (m : BitLayout),
    m.dom = 2 ^ d - 1 → (placeModes ms d m).dom = 2 ^ (d + (ms.map fun p => log2 p.1).sum) - 1
  | [], _, _, h => by simp only [placeModes, List.map_nil, List.sum_nil, Nat.add_zero]; exact h
  | (e, s) :: ms, d, m, h => by
    simp only [placeModes, List.map_cons, List.sum_cons]
    rw [placeModes_dom ms _ _ (placeMode_dom s _ d 0 m h), Nat.add_assoc]

/-- `log2` of `2 ^ k` is `k`, for `k` below the bit count. -/
theorem trailingZeros_two_pow : ∀ (f k : Nat), k < f → trailingZeros f (2 ^ k) = k
  | 0, _, h => absurd h (Nat.not_lt_zero _)
  | f + 1, 0, _ => by simp [trailingZeros]
  | f + 1, k + 1, h => by
    have h2 : ¬ (2 ^ (k + 1) % 2 = 1) := by simp [Nat.pow_succ]
    simp only [trailingZeros, h2, ↓reduceIte]
    rw [Nat.pow_succ, Nat.mul_div_cancel _ (by decide), trailingZeros_two_pow f k (by omega)]

/-- A power of two below `2 ^ 64` is `2 ^ log2 n`. -/
theorem log2_pow (n : Nat) (h : powerOfTwo n = true) (hw : n < 2 ^ 64) : n = 2 ^ log2 n := by
  simp only [powerOfTwo, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at h
  obtain ⟨k, rfl⟩ := (Nat.and_sub_one_eq_zero_iff_isPowerOfTwo (by omega)).mp h.2
  rw [log2, trailingZeros_two_pow 64 k ((Nat.pow_lt_pow_iff_right (by decide)).mp hw)]

/-- The images of the domain bits that `placeModes` places, XORed over the point `x`, are the
offset `dotColex` of `x`, and miss `reached`. For every flat layout that `bitLinear` accepts from
`reached`, with extents and strides below `2 ^ 64`, and every point. -/
theorem xorBits_place : ∀ (ms : List (Nat × Nat)) (R d : Nat) (m : BitLayout),
    bitLinear ms R = true → (∀ p ∈ ms, p.1 < 2 ^ 64 ∧ p.2 < 2 ^ 64) → ∀ x,
    xorBits (placeModes ms d m).img d (ms.map fun p => log2 p.1).sum x &&& R = 0 ∧
      xorBits (placeModes ms d m).img d (ms.map fun p => log2 p.1).sum x = dotColex ms x
  | [], R, d, m, _, _, x => by simp [xorBits, dotColex, colex]
  | (e, s) :: ms, R, d, m, h, hw, x => by
    simp only [List.mem_cons, forall_eq_or_imp] at hw
    simp only [bitLinear, Bool.and_eq_true] at h
    obtain ⟨he, h⟩ := h
    have hE := log2_pow e he hw.1.1
    generalize hk : log2 e = k at hE
    have hd : dotColex ((e, s) :: ms) x = x % 2 ^ k * s + dotColex ms (x / 2 ^ k) := by
      simp [dotColex, colex, hE]
    simp only [placeModes, List.map_cons, List.sum_cons, hk]
    rw [xorBits_add, hd]
    have hi : ∀ j, j < k → (placeModes ms (d + k) (placeMode s d 0 k m)).img (d + j) =
        s * 2 ^ j := fun j hj => by
      rw [placeModes_img_lt ms _ _ _ (by omega), placeMode_img s k d 0 m j hj, Nat.zero_add]
    by_cases h0 : s = 0
    · subst h0
      simp only [↓reduceIte] at h
      obtain ⟨ih1, ih2⟩ := xorBits_place ms R (d + k) (placeMode 0 d 0 k m) h hw.2 (x / 2 ^ k)
      rw [xorBits_stride _ k d 0 (Or.inl rfl) hi x]
      simp only [Nat.mul_zero, Nat.zero_xor, Nat.zero_add]
      exact ⟨ih1, ih2⟩
    · simp only [h0, ↓reduceIte, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨hs, hR⟩, hl⟩ := h
      have hS := log2_pow s hs hw.1.2
      generalize ht : log2 s = t at hS hR hl
      rw [hk] at hR hl
      obtain ⟨ih1, ih2⟩ := xorBits_place ms _ (d + k) (placeMode s d 0 k m) hl hw.2 (x / 2 ^ k)
      rw [xorBits_stride _ k d s (Or.inr ⟨t, hS⟩) hi x]
      generalize xorBits _ (d + k) _ (x / 2 ^ k) = T at ih1 ih2
      have hsub := and_bitsMask x k t
      rw [← hS] at hsub
      rw [Nat.and_or_distrib_left, Nat.or_eq_zero_iff] at ih1
      have hTS : bitsMask t k &&& T = 0 := by rw [Nat.and_comm]; exact ih1.2
      have hSR : bitsMask t k &&& R = 0 := by rw [Nat.and_comm]; exact hR
      refine ⟨?_, ?_⟩
      · rw [Nat.and_xor_distrib_right, and_eq_zero_of_sub _ _ _ hsub hSR, ih1.1, Nat.xor_zero]
      · rw [xor_eq_add _ _ (and_eq_zero_of_sub _ _ _ hsub hTS), ih2]

/-- **A bit-linear layout is its placement** (bit-layout card): on every flat static layout that
`is_bit_linear` accepts (every extent a power of two, every stride 0 or a power of two, and no
offset bit reached by two coordinate bits), with extents and strides below `2 ^ 64` (Mojo's are
`Int`s) and a size of at most `2 ^ 64` (the points are `UInt64`s), the placement's domain mask is
the size minus 1, so its domain bits are those of the points below the size, and its value at
every point `x` below the size is the layout's offset of `x`: the XOR of the images of `x`'s
bits is the sum of each digit times its stride. -/
theorem placement_call (ms : List (Nat × Nat)) (h : isBitLinear ms = true)
    (hw : ∀ p ∈ ms, p.1 < 2 ^ 64 ∧ p.2 < 2 ^ 64) (hs : (Lay.flat ms).size ≤ 2 ^ 64) :
    (placement ms).dom = (Lay.flat ms).size - 1 ∧ ∀ (x : Nat) (b : Bool),
      x < (Lay.flat ms).size → (placement ms).call x = (Lay.flat ms).call (leaf x b) := by
  have hsize : (Lay.flat ms).size = 2 ^ (ms.map fun p => log2 p.1).sum := by
    rw [Lay.size_flat]
    clear hs
    unfold isBitLinear at h
    generalize 0 = R at h
    induction ms generalizing R with
    | nil => rfl
    | cons p ms ih =>
      obtain ⟨e, s⟩ := p
      simp only [List.mem_cons, forall_eq_or_imp] at hw
      simp only [bitLinear, Bool.and_eq_true] at h
      simp only [List.map_cons, List.prod_cons, List.sum_cons, Nat.pow_add]
      rw [← log2_pow e h.1 hw.1.1]
      by_cases h0 : s = 0
      · simp only [h0, ↓reduceIte] at h
        rw [ih hw.2 R h.2]
      · simp only [h0, ↓reduceIte, Bool.and_eq_true] at h
        rw [ih hw.2 _ h.2.2]
  refine ⟨by rw [hsize, placement, placeModes_dom ms 0 _ rfl, Nat.zero_add], fun x b hx => ?_⟩
  have hK : (ms.map fun p => log2 p.1).sum ≤ 64 :=
    (Nat.pow_le_pow_iff_right (by decide)).mp (hsize ▸ hs)
  have hx' : x < 2 ^ (ms.map fun p => log2 p.1).sum := hsize ▸ hx
  rw [((Lay.flat ms).modes_size_call (Lay.flat_congruent ms)).2 x b hx, Lay.modes_flat,
    BitLayout.call, placement, placeModes_dom ms 0 _ rfl, Nat.zero_add,
    Nat.and_two_pow_sub_one_eq_mod, Nat.mod_eq_of_lt hx', xorBits_of_lt _ _ _ _ _ hK hx']
  exact (xorBits_place ms 0 0 _ h hw x).2

end GPUProof.Layout
