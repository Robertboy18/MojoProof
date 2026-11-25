import MojoProof.Layout.Bits
import MojoProof.Layout.Swizzle

/-!
# The two-level swizzle

`TwoLevelLayout` of max/kernels/src/layout/two_level_layout.mojo at modular/modular bbc13a71,
whose outer layout is flat and static, and its constructor from a swizzle (lines 1101-1133), which
builds the two-level layout of a `Swizzle` and a flat static layout, transcribed over the model of
MojoProof/Layout/Basic.lean and the swizzle of MojoProof/Layout/Algebra.lean, with their law, for
every swizzle and every layout that passes the constructor's two asserts:

* `Swizzle.twoLevel_call`: at every tuple coordinate inside the shape and every scalar index below
  the size, the two-level layout's value is the swizzle of the layout's offset, `Swizzle(L(x))`,
  as the constructor's docstring states (two_level_layout.mojo:1106-1109).

The proof reuses the swizzle's linearity (`Swizzle.call_xor`) and the bit layouts' `xorBits`
lemmas. The model computes on natural numbers where Mojo computes on `Int`s; the two agree while
every extent, stride and offset lies below `2 ^ 63`.
-/

namespace MojoProof.Layout

open Tup

/-! ## The transcription -/

/-- `_TwoLevelLayout` (two_level_layout.mojo:471-631) whose outer layout is flat and static: the
(extent, stride) modes `outer` of the outer layout, the comptime basis images `inner`, one list per
mode whose entry `j` is the image of the mode's inner bit `j` (`_InnerImage`, line 86; the list's
length is `_InnerBitCount`, line 63), and the XOR base `x0`. Nested and runtime outer layouts are
not modelled. -/
structure TwoLevel where
  /-- The two-level layout of the outer modes `outer`, the inner images `inner` and the base
  `x0`. -/
  mk ::
  /-- The (extent, stride) modes of the outer layout. -/
  outer : List (Nat × Nat)
  /-- The images of each mode's inner bits, lowest bit first. -/
  inner : List (List Nat)
  /-- The XOR base. -/
  x0 : Nat

/-- The inner bits of `__call__` (two_level_layout.mojo:684-691): over the modes, the XOR of the
images `imgs[b]` of the set bits `b` among the `imgs.length` low bits of each mode's value. -/
def innerXor : List (List Nat) → List Nat → Nat
  | imgs :: iss, v :: c => xorBits (fun j => imgs.getD j 0) 0 imgs.length v ^^^ innerXor iss c
  | _, _ => 0

/-- The full shape of a two-level layout (`_FullShapeTabulator`, two_level_layout.mojo:240-248):
each outer extent shifted left by the mode's number of inner bits. -/
def TwoLevel.shape (T : TwoLevel) : List Nat :=
  List.zipWith (fun p imgs => p.1 <<< imgs.length) T.outer T.inner

/-- `TwoLevelLayout.__call__` (two_level_layout.mojo:633-698) on the mode values `c`: each value
gives its `k` low bits to the inner map and keeps `value >> k` as its outer coordinate (lines
682-695), and the result is `Outer(outer_coord) + (x0 ^ inner_bits)` (line 697). -/
def TwoLevel.offset (T : TwoLevel) (c : List Nat) : Nat :=
  (Lay.flat T.outer).call
      (tup ((List.zipWith (fun imgs v => v >>> imgs.length) T.inner c).map (leaf · false))) +
    (T.x0 ^^^ innerXor T.inner c)

/-- `TwoLevelLayout.__call__` (two_level_layout.mojo:633-698): a tuple coordinate gives its leaves'
values as the mode values (lines 656-665), and a scalar index `n` is split by `divmod` by each
full extent in turn (lines 666-680), colexicographically. Mojo rejects a nested coordinate and one
of another rank at compile time (lines 657-664); the model reads a nested child as 0. -/
def TwoLevel.call (T : TwoLevel) : Tup → Nat
  | leaf n _ => T.offset (colex n T.shape)
  | tup ts => T.offset (ts.map Tup.value)

/-- `_SwizzlePeriod` (two_level_layout.mojo:956-959): `base + bits + |shift|`, the offset bit from
which on the swizzle changes nothing (`Swizzle.testBit_call`). -/
def Swizzle.period (S : Swizzle) : Nat := S.base + S.bits + S.shift.natAbs

/-- `_SwizzleInnerBits` (two_level_layout.mojo:962-976): the number of low bits of the mode
(extent, stride) `p` that lie below the swizzle's period, `min(log2 extent, max(0, period -
log2 stride))` when the extent and the stride are powers of two (`_PowerOfTwo`, line 145, is
`powerOfTwo`), and 0 otherwise. Mojo takes `log2_floor` (`_log2_or_zero`, line 140), which `log2`
of MojoProof/Layout/Bits.lean equals on the powers of two below `2 ^ 64`. -/
def Swizzle.innerBits (S : Swizzle) (p : Nat × Nat) : Nat :=
  if powerOfTwo p.1 && powerOfTwo p.2 then min (log2 p.1) (S.period - log2 p.2) else 0

/-- `two_level_layout_from_swizzle` (two_level_layout.mojo:1101-1133) of the swizzle `S` and the
flat static layout of the modes `ms`: `SwizzledTwoLevelLayout` (lines 1049-1064), whose outer
layout `_SwizzleOuter` (lines 1015-1047) has the extents `extent >> k` and the strides
`stride << k`, whose inner images `_SwizzleInner` (lines 978-1013) are `Swizzle(stride << j)` for
`j < k` (`_SwizzleImage`, lines 950-953, is `Swizzle.call`), and whose base is 0 (line 1133),
where `k` is the mode's `Swizzle.innerBits`. Mojo's asserts (lines 1125-1132) are `swizzleValid`
and `Swizzle.disjoint`; the model builds the layout whether they hold or not. -/
def Swizzle.twoLevel (S : Swizzle) (ms : List (Nat × Nat)) : TwoLevel :=
  ⟨ms.map fun p => (p.1 >>> S.innerBits p, p.2 <<< S.innerBits p),
    ms.map fun p => (List.range (S.innerBits p)).map fun j => S.call (p.2 <<< j), 0⟩

/-- `_swizzle_layout_valid` (two_level_layout.mojo:1066-1078) of a flat static layout: every extent
and every stride is a power of two. Its other checks, a static and flat layout, hold of every
model layout `Lay.flat ms`. -/
def swizzleValid (ms : List (Nat × Nat)) : Bool :=
  ms.all fun p => powerOfTwo p.1 && powerOfTwo p.2

/-- `_swizzle_inner_bits_disjoint` (two_level_layout.mojo:1081-1098) from the mask `seen` of the
offset bits that earlier modes' inner bits reach: the `k` inner bits of each mode reach the offset
bits `log2(stride) + b` for `b < k`, the span `bitsMask (log2 stride) k`, which must miss `seen`
and joins it. Mojo tests and sets the bits one at a time; within one mode they are distinct. -/
def Swizzle.disjoint (S : Swizzle) : List (Nat × Nat) → Nat → Bool
  | [], _ => true
  | p :: ms, r => r &&& bitsMask (log2 p.2) (S.innerBits p) == 0 &&
      S.disjoint ms (r ||| bitsMask (log2 p.2) (S.innerBits p))

/-! ## The swizzle above its period -/

/-- The bits of the swizzle's mask lie below `base + bits + max(shift, 0)`. -/
theorem Swizzle.testBit_mask (S : Swizzle) (i : Nat) (h : S.mask.testBit i = true) :
    i < S.base + S.bits + S.shift.toNat := by
  simp only [Swizzle.mask, Nat.testBit_shiftLeft, Nat.testBit_two_pow_sub_one, Bool.and_eq_true,
    decide_eq_true_eq] at h
  omega

/-- The swizzle changes no offset bit from its period on. For every swizzle and every value. -/
theorem Swizzle.testBit_call (S : Swizzle) (y j : Nat) (hj : S.period ≤ j) :
    (S.call y).testBit j = y.testBit j := by
  simp only [Swizzle.period] at hj
  have h0 : (shiftr (y &&& S.mask) S.shift).testBit j = false := by
    unfold shiftr
    split
    · rw [Nat.testBit_shiftRight, Nat.testBit_and]
      cases hb : S.mask.testBit (S.shift.toNat + j)
      · simp
      · exact absurd (S.testBit_mask _ hb) (by omega)
    · rw [Nat.testBit_shiftLeft, Nat.testBit_and]
      cases hb : S.mask.testBit (j - (-S.shift).toNat)
      · simp
      · exact absurd (S.testBit_mask _ hb) (by omega)
  rw [Swizzle.call, Nat.testBit_xor, h0, Bool.xor_false]

/-- A multiple of `2 ^ n` and a number below `2 ^ n` have no common bit. -/
theorem and_eq_zero_of_lt (q y n : Nat) (hy : y < 2 ^ n) : 2 ^ n * q &&& y = 0 := by
  apply Nat.eq_of_testBit_eq
  intro j
  simp only [Nat.testBit_and, Nat.testBit_two_pow_mul, Nat.zero_testBit]
  by_cases hj : n ≤ j
  · rw [Nat.testBit_lt_two_pow (Nat.lt_of_lt_of_le hy (Nat.pow_le_pow_right (by decide) hj))]
    simp
  · simp [show ¬ j ≥ n by omega]

/-- The swizzle of a value below `2 ^ period` is below `2 ^ period`. For every swizzle. -/
theorem Swizzle.call_lt (S : Swizzle) (y : Nat) (hy : y < 2 ^ S.period) :
    S.call y < 2 ^ S.period :=
  Nat.lt_pow_two_of_testBit _ fun j hj => by
    rw [S.testBit_call y j hj]
    exact Nat.testBit_lt_two_pow (Nat.lt_of_lt_of_le hy (Nat.pow_le_pow_right (by decide) hj))

/-- Adding a multiple of `2 ^ period` commutes with the swizzle, on a value below `2 ^ period`.
For every swizzle. -/
theorem Swizzle.call_add (S : Swizzle) (q y : Nat) (hy : y < 2 ^ S.period) :
    S.call (2 ^ S.period * q + y) = 2 ^ S.period * q + S.call y := by
  have hm : S.mask < 2 ^ S.period := Nat.lt_pow_two_of_testBit _ fun j hj => by
    simp only [Swizzle.period] at hj
    cases hb : S.mask.testBit j
    · rfl
    · exact absurd (S.testBit_mask _ hb) (by omega)
  rw [← xor_eq_add _ _ (and_eq_zero_of_lt q y _ hy), S.call_xor,
    ← xor_eq_add _ _ (and_eq_zero_of_lt q _ _ (S.call_lt y hy))]
  congr 1
  simp only [Swizzle.call, and_eq_zero_of_lt q _ _ hm, shiftr]
  split <;> simp

/-! ## The law -/

/-- `xorBits` commutes with a map that is linear over F2: when each image is the map of another
image, the XOR of the images is the map of the XOR of the others. -/
theorem xorBits_map (f : Nat → Nat) (hf : ∀ a b, f (a ^^^ b) = f a ^^^ f b) (img img' : Nat → Nat) :
    ∀ n i, (∀ j, j < n → img (i + j) = f (img' (i + j))) → ∀ y,
      xorBits img i n y = f (xorBits img' i n y) := by
  have h0 : f 0 = 0 := by simpa using hf 0 0
  intro n
  induction n with
  | zero => intro i _ y; simp [xorBits, h0]
  | succ n ih =>
    intro i hi y
    have e := ih (i + 1) (fun j hj => by
      rw [show i + 1 + j = i + (j + 1) by omega]; exact hi (j + 1) (by omega)) (y / 2)
    have hi0 : img i = f (img' i) := by simpa using hi 0 (by omega)
    simp only [xorBits, e, hf]
    split <;> simp [hi0, h0]

/-- The pieces of the two-level swizzle, mode by mode, for every flat layout that passes the
asserts from the mask `reached` and every coordinate inside the shape: the outer offset plus the
inner offset is the layout's offset; the outer offset is a multiple of `2 ^ period`; the inner
offset is below `2 ^ period` and misses `reached`; and the inner bits are its swizzle. -/
theorem Swizzle.twoLevel_parts (S : Swizzle) : ∀ (ms : List (Nat × Nat)) (c : List Nat) (R : Nat),
    swizzleValid ms = true → (∀ p ∈ ms, p.1 < 2 ^ 64 ∧ p.2 < 2 ^ 64) → S.disjoint ms R = true →
    c.length = ms.length → (∀ vp ∈ c.zip ms, vp.1 < vp.2.1) →
    (List.zipWith (fun v p => (v >>> S.innerBits p) * (p.2 <<< S.innerBits p)) c ms).sum +
        (List.zipWith (fun v p => v % 2 ^ S.innerBits p * p.2) c ms).sum =
      (List.zipWith (· * ·) c (ms.map Prod.snd)).sum ∧
    2 ^ S.period ∣
      (List.zipWith (fun v p => (v >>> S.innerBits p) * (p.2 <<< S.innerBits p)) c ms).sum ∧
    (List.zipWith (fun v p => v % 2 ^ S.innerBits p * p.2) c ms).sum < 2 ^ S.period ∧
    (List.zipWith (fun v p => v % 2 ^ S.innerBits p * p.2) c ms).sum &&& R = 0 ∧
    innerXor (ms.map fun p => (List.range (S.innerBits p)).map fun j => S.call (p.2 <<< j)) c =
      S.call (List.zipWith (fun v p => v % 2 ^ S.innerBits p * p.2) c ms).sum
  | [], [], R, _, _, _, _, _ => by
    simp [innerXor, Swizzle.call, shiftr, Nat.two_pow_pos]
  | [], _ :: _, _, _, _, _, h, _ => by simp at h
  | _ :: _, [], _, _, _, _, h, _ => by simp at h
  | (e, s) :: ms, v :: c, R, hv, hw, hd, hl, hb => by
    simp only [swizzleValid, List.all_cons, Bool.and_eq_true] at hv
    simp only [List.mem_cons, forall_eq_or_imp] at hw
    simp only [Swizzle.disjoint, Bool.and_eq_true, beq_iff_eq] at hd
    simp only [List.zip_cons_cons, List.mem_cons, forall_eq_or_imp] at hb
    simp only [List.length_cons, Nat.add_right_cancel_iff] at hl
    obtain ⟨i1, i2, i3, i4, i5⟩ := S.twoLevel_parts ms c _ hv.2 hw.2 hd.2 hl hb.2
    have hE := log2_pow e hv.1.1 hw.1.1
    have hS := log2_pow s hv.1.2 hw.1.2
    have hk : S.innerBits (e, s) = min (log2 e) (S.period - log2 s) := by
      simp [Swizzle.innerBits, hv.1.1, hv.1.2]
    simp only [List.zipWith_cons_cons, List.sum_cons, List.map_cons, innerXor, List.length_map,
      List.length_range]
    generalize S.innerBits (e, s) = k at hk hd i1 i2 i3 i4 i5 ⊢
    generalize log2 s = t at hS hk hd i4
    generalize (List.zipWith (fun v p => v % 2 ^ S.innerBits p * p.2) c ms).sum = Y
      at i1 i3 i4 i5
    rw [Nat.and_or_distrib_left, Nat.or_eq_zero_iff] at i4
    have ha : v % 2 ^ k * s &&& bitsMask t k = v % 2 ^ k * s := hS ▸ and_bitsMask v k t
    have haR : v % 2 ^ k * s &&& R = 0 :=
      and_eq_zero_of_sub _ _ _ ha (by rw [Nat.and_comm]; exact hd.1)
    have haY : v % 2 ^ k * s &&& Y = 0 :=
      and_eq_zero_of_sub _ _ _ ha (by rw [Nat.and_comm]; exact i4.2)
    have hsum : v % 2 ^ k * s + Y = v % 2 ^ k * s ^^^ Y := (xor_eq_add _ _ haY).symm
    refine ⟨?_, ?_, ?_, ?_, ?_⟩
    · rw [← i1, Nat.shiftRight_eq_div_pow, Nat.shiftLeft_eq]
      have h := Nat.div_add_mod v (2 ^ k)
      have h2 : v / 2 ^ k * (s * 2 ^ k) + v % 2 ^ k * s = v * s := by
        rw [Nat.mul_comm s (2 ^ k), ← Nat.mul_assoc, Nat.mul_comm (v / 2 ^ k) (2 ^ k),
          ← Nat.add_mul, h]
      omega
    · refine Nat.dvd_add ?_ i2
      by_cases hc : log2 e ≤ S.period - t
      · have : k = log2 e := by omega
        rw [this, Nat.shiftRight_eq_div_pow, ← hE, Nat.div_eq_of_lt hb.1]
        simp
      · have : k = S.period - t := by omega
        refine Nat.dvd_mul_left_of_dvd ?_ _
        rw [Nat.shiftLeft_eq, hS, ← Nat.pow_add]
        exact Nat.pow_dvd_pow 2 (by omega)
    · rw [hsum]
      refine Nat.xor_lt_two_pow ?_ i3
      by_cases hk0 : k = 0
      · rw [hk0, Nat.pow_zero, Nat.mod_one, Nat.zero_mul]
        exact Nat.two_pow_pos _
      · calc v % 2 ^ k * s < 2 ^ k * s :=
              Nat.mul_lt_mul_of_pos_right (Nat.mod_lt _ (Nat.two_pow_pos _))
                (by rw [hS]; exact Nat.two_pow_pos _)
          _ = 2 ^ (k + t) := by rw [hS, Nat.pow_add]
          _ ≤ 2 ^ S.period := Nat.pow_le_pow_right (by decide) (by omega)
    · rw [hsum, Nat.and_xor_distrib_right, haR, i4.1, Nat.xor_zero]
    · rw [i5, hsum, S.call_xor]
      congr 1
      rw [xorBits_map S.call S.call_xor _ (fun j => s * 2 ^ j) k 0 (fun j hj => by
          simp only [Nat.zero_add] at hj ⊢
          simp [List.getD_eq_getElem?_getD, List.getElem?_range hj, Nat.shiftLeft_eq])]
      rw [xorBits_stride _ k 0 s (Or.inr ⟨t, hS⟩) (fun j _ => by simp) v]

/-- **The two-level swizzle is the swizzle of the layout** (two-level-swizzle card): for every
swizzle (any number of bits, base and shift, positive or not) and every flat static layout that
passes the asserts of `two_level_layout_from_swizzle` (two_level_layout.mojo:1125-1132), every
extent and stride a power of two and no offset bit reached by the inner bits of two modes, with
extents and strides below `2 ^ 64`, the two-level layout's value is `Swizzle(L(x))` (lines
1106-1109) at every tuple coordinate with one leaf per mode, each inside its extent, and at every
scalar index below the size. -/
theorem Swizzle.twoLevel_call (S : Swizzle) (ms : List (Nat × Nat)) (hv : swizzleValid ms = true)
    (hd : S.disjoint ms 0 = true) (hw : ∀ p ∈ ms, p.1 < 2 ^ 64 ∧ p.2 < 2 ^ 64) :
    (∀ (c : List Nat) (b : Bool), c.length = ms.length → (∀ vp ∈ c.zip ms, vp.1 < vp.2.1) →
      (S.twoLevel ms).call (tup (c.map (leaf · b))) =
        S.call ((Lay.flat ms).call (tup (c.map (leaf · b))))) ∧
    ∀ (x : Nat) (b : Bool), x < (Lay.flat ms).size →
      (S.twoLevel ms).call (leaf x b) = S.call ((Lay.flat ms).call (leaf x b)) := by
  have hoff : ∀ c, c.length = ms.length → (∀ vp ∈ c.zip ms, vp.1 < vp.2.1) →
      (S.twoLevel ms).offset c = S.call (List.zipWith (· * ·) c (ms.map Prod.snd)).sum := by
    intro c hl hb
    obtain ⟨i1, i2, i3, -, i5⟩ := S.twoLevel_parts ms c 0 hv hw hd hl hb
    obtain ⟨q, hq⟩ := i2
    have hz : List.zipWith (fun imgs v => v >>> imgs.length) (S.twoLevel ms).inner c =
        List.zipWith (fun v p => v >>> S.innerBits p) c ms := by
      clear i1 hq i3 i5 hb hv hd hw
      induction ms generalizing c with
      | nil => simp [Swizzle.twoLevel]
      | cons p ms ih =>
        cases c with
        | nil => simp at hl
        | cons v c => simpa [Swizzle.twoLevel] using ih c (by simpa using hl)
    have hd' : (List.zipWith (· * ·) (List.zipWith (fun v p => v >>> S.innerBits p) c ms)
        ((S.twoLevel ms).outer.map Prod.snd)).sum =
        (List.zipWith (fun v p => (v >>> S.innerBits p) * (p.2 <<< S.innerBits p)) c ms).sum := by
      clear i1 hq i3 i5 hb hv hd hw hz
      induction ms generalizing c with
      | nil => simp [Swizzle.twoLevel]
      | cons p ms ih =>
        cases c with
        | nil => simp at hl
        | cons v c => simpa [Swizzle.twoLevel] using ih c (by simpa using hl)
    rw [TwoLevel.offset, hz, Lay.call_flat _ _ _ (by simp [Swizzle.twoLevel, hl]), hd']
    show _ + (0 ^^^ innerXor (ms.map fun p =>
      (List.range (S.innerBits p)).map fun j => S.call (p.2 <<< j)) c) = _
    rw [Nat.zero_xor, i5, ← i1, hq, S.call_add q _ i3]
  refine ⟨fun c b hl hb => ?_, fun x b hx => ?_⟩
  · rw [Lay.call_flat ms c b hl, ← hoff c hl hb, TwoLevel.call, List.map_map]
    congr 1
    simp [Function.comp_def, Tup.value]
  · have hsh : (S.twoLevel ms).shape = ms.map Prod.fst := by
      clear hoff hd hx
      induction ms with
      | nil => rfl
      | cons p ms ih =>
        simp only [swizzleValid, List.all_cons, Bool.and_eq_true] at hv
        simp only [List.mem_cons, forall_eq_or_imp] at hw
        have hE := log2_pow p.1 hv.1.1 hw.1.1
        have hk : S.innerBits p ≤ log2 p.1 := by
          unfold Swizzle.innerBits
          split <;> omega
        have e : p.1 >>> S.innerBits p <<< S.innerBits p = p.1 := by
          rw [Nat.shiftRight_eq_div_pow, Nat.shiftLeft_eq, hE, Nat.pow_div (by omega) (by decide),
            ← Nat.pow_add, Nat.sub_add_cancel hk]
        have := ih hv.2 hw.2
        simp only [TwoLevel.shape, Swizzle.twoLevel, List.map_cons, List.zipWith_cons_cons,
          List.length_map, List.length_range] at this ⊢
        rw [e, this]
    have hpos : ∀ s ∈ ms.map Prod.fst, 0 < s := by
      intro s hs
      obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hs
      have := (List.all_eq_true.mp hv) p hp
      simp only [Bool.and_eq_true, powerOfTwo, decide_eq_true_eq] at this
      exact this.1.1
    have hcl : (colex x (ms.map Prod.fst)).length = ms.length := by
      rw [colex_length, List.length_map]
    have hcb : ∀ vp ∈ (colex x (ms.map Prod.fst)).zip ms, vp.1 < vp.2.1 := by
      clear hoff hsh hd hx hcl hv hw
      induction ms generalizing x with
      | nil => simp [colex]
      | cons p ms ih =>
        simp only [List.map_cons, colex, List.zip_cons_cons, List.mem_cons, forall_eq_or_imp]
        simp only [List.map_cons, List.mem_cons, forall_eq_or_imp] at hpos
        exact ⟨Nat.mod_lt _ hpos.1, ih _ hpos.2⟩
    rw [((Lay.flat ms).modes_size_call (Lay.flat_congruent ms)).2 x b hx, Lay.modes_flat,
      dotColex, TwoLevel.call, hsh, hoff _ hcl hcb]

end MojoProof.Layout
