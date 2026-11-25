import Mathlib.Algebra.BigOperators.Group.List.Basic

/-!
# Mixed-radix indices at symbolic sizes

An index that a kernel computes from its launch registers and sizes, such as a warp's row
`(ctaid * ntid + tid) / W` or a matrix entry's offset `row * n + k`, is often a number in a mixed
radix: digits, each below its own radix, valued by Horner's rule. The radices are symbolic, so the
facts hold for every size assignment, and a theorem about such an index fixes no size.

* `SizeExpr`: a size, a term over the variables of a size assignment (`Sizes`: sizes, launch
  registers, member counts, bound indices), products and quotients; `SizeExpr.eval`.
* `MixedRadix`: digits with their radices, both `SizeExpr`s, the least significant digit first;
  `val` (Horner's rule), `digitVals`, `radixProd` and `InRange` (each digit below its radix).
* `WordFit w k`: what a width of `w` bits keeps of the index `k`. The `w`-bit word of `k` has the
  unsigned and the signed value `k`, its sign extension to every width is the word of `k` there,
  and for every `a + b = k` the add of the words of `a` and `b` wraps neither unsigned
  (`BitVec.uaddOverflow`) nor signed (`BitVec.saddOverflow`, so neither `nuw` nor `nsw` holds it
  back) and gives the word of `k`. `WordFit.of_lt` proves it below `2 ^ (w - 1)`.

Proved, for every size assignment, radix list and width:

* `MixedRadix.lt_prod`: an index in range is below the product of its radices.
* `MixedRadix.eq_iff_digits`: for every two size assignments, two indices in range whose radices
  have the same values are equal exactly when their digits are. This decides
  `r * n + k = r' * n + k'` at symbolic `n` with `k, k' < n`, which `omega` cannot, since the
  products are of two unknowns, and compares two instances of one index at their own coordinates.
* `MixedRadix.val_append`: Horner's rule split at a digit, the value of `a ++ b` is the value of
  `a` plus the radix product of `a` times the value of `b`.
* `MixedRadix.fits`: an index in range whose radix product is below `2 ^ (w - 1)` fits `w` bits.

Mathlib has the value of digits in one base (`Nat.ofDigits`), its injectivity at a fixed length
(`Nat.ofDigits_inj_of_len_eq`) and the two-digit mixed radix (`finProdFinEquiv`, `y + n * x`);
the proofs here use its division and remainder lemmas digit by digit.
-/

namespace GPUProof

/-- A size assignment: the value of each size variable, numbered. A variable may stand for a
size, a launch register, the member count of a level instance or a bound index. -/
abbrev Sizes := Nat → Nat

/-- A size, symbolic: a variable of the size assignment, a product or a quotient. -/
inductive SizeExpr where
  /-- The size variable numbered `v`. -/
  | var (v : Nat)
  /-- The product of two sizes. -/
  | mul (a b : SizeExpr)
  /-- The quotient of two sizes, rounded down (`0` when the divisor is `0`, as `Nat.div`). -/
  | div (a b : SizeExpr)
  deriving DecidableEq

/-- Decidable equality of sizes, constructor by constructor, derived. -/
add_decl_doc instDecidableEqSizeExpr

/-- The value of a size at the size assignment `σ`. -/
def SizeExpr.eval (σ : Sizes) : SizeExpr → Nat
  | .var v => σ v
  | .mul a b => a.eval σ * b.eval σ
  | .div a b => a.eval σ / b.eval σ

/-- A mixed-radix index: digits, each with its radix, both symbolic sizes, the least significant
first. -/
structure MixedRadix where
  /-- The index with the digits `digits`. -/
  mk ::
  /-- The digits with their radices, the least significant first. -/
  digits : List (SizeExpr × SizeExpr)
  deriving DecidableEq

/-- Decidable equality of mixed-radix indices, digit by digit, derived. -/
add_decl_doc instDecidableEqMixedRadix

namespace MixedRadix

/-- The value of index `x` at the size assignment `σ`, by Horner's rule: `d₀ + r₀ (d₁ + r₁ (…))`
for the digits `dᵢ` with radices `rᵢ`. -/
def val (x : MixedRadix) (σ : Sizes) : Nat :=
  x.digits.foldr (fun p v => p.1.eval σ + p.2.eval σ * v) 0

/-- The values of the digits of index `x` at the size assignment `σ`. -/
def digitVals (x : MixedRadix) (σ : Sizes) : List Nat := x.digits.map fun p => p.1.eval σ

/-- The product of the radices of index `x` at the size assignment `σ`. -/
def radixProd (x : MixedRadix) (σ : Sizes) : Nat := (x.digits.map fun p => p.2.eval σ).prod

/-- Each digit of index `x` is below its radix at the size assignment `σ`. -/
def InRange (x : MixedRadix) (σ : Sizes) : Prop := ∀ p ∈ x.digits, p.1.eval σ < p.2.eval σ

/-- `InRange` is decided digit by digit. -/
instance (x : MixedRadix) (σ : Sizes) : Decidable (x.InRange σ) :=
  inferInstanceAs (Decidable (∀ p ∈ x.digits, p.1.eval σ < p.2.eval σ))

/-- **An index in range is below the product of its radices**, for every size assignment and
radix list. -/
theorem lt_prod {x : MixedRadix} {σ : Sizes} (hx : x.InRange σ) : x.val σ < x.radixProd σ := by
  obtain ⟨ds⟩ := x
  induction ds with
  | nil => simp [val, radixProd]
  | cons p ds ih =>
    have hx' : ∀ q ∈ p :: ds, q.1.eval σ < q.2.eval σ := hx
    have hp := hx' p List.mem_cons_self
    have ht := ih fun q hq => hx' q (List.mem_cons_of_mem p hq)
    simp only [val, radixProd, List.foldr_cons, List.map_cons, List.prod_cons] at ht ⊢
    calc p.1.eval σ + p.2.eval σ * _ < p.2.eval σ + p.2.eval σ * _ := Nat.add_lt_add_right hp _
      _ = p.2.eval σ * (_ + 1) := by rw [Nat.mul_succ, Nat.add_comm]
      _ ≤ p.2.eval σ * _ := Nat.mul_le_mul_left _ ht

/-- One digit below its radix `r` and the rest: `a + r v = b + r v'` exactly when `a = b` and
`v = v'`, for all numbers with `a, b < r`. -/
theorem add_mul_eq_iff {a b r v v' : Nat} (ha : a < r) (hb : b < r) :
    a + r * v = b + r * v' ↔ a = b ∧ v = v' := by
  constructor
  · intro h
    have hm := congrArg (· % r) h
    have hd := congrArg (· / r) h
    simp only [Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt ha, Nat.mod_eq_of_lt hb] at hm
    simp only [Nat.add_mul_div_left _ _ (Nat.lt_of_le_of_lt (Nat.zero_le a) ha),
      Nat.div_eq_of_lt ha, Nat.div_eq_of_lt hb, Nat.zero_add] at hd
    exact ⟨hm, hd⟩
  · rintro ⟨rfl, rfl⟩
    rfl

/-- **Indices with the same radix values are equal exactly when their digits are**, for every two
size assignments `σ`, `τ` and radix lists: when `x` is in range at `σ`, `y` at `τ` (`InRange`), and
the radices of `x` at `σ` have the values of the radices of `y` at `τ`, the value of `x` at `σ` is
the value of `y` at `τ` exactly when their digits have the same values. At one assignment this
decides `r * n + k = r' * n + k'` at symbolic `n`, which `omega` cannot; at two, it compares two
instances of one index, each with its own coordinates. -/
theorem eq_iff_digits {x y : MixedRadix} {σ τ : Sizes} (hx : x.InRange σ) (hy : y.InRange τ)
    (hr : x.digits.map (fun p => p.2.eval σ) = y.digits.map (fun p => p.2.eval τ)) :
    x.val σ = y.val τ ↔ x.digitVals σ = y.digitVals τ := by
  obtain ⟨ds⟩ := x
  obtain ⟨es⟩ := y
  induction ds generalizing es with
  | nil =>
    cases es with
    | nil => simp [val, digitVals]
    | cons q es => simp at hr
  | cons p ds ih =>
    cases es with
    | nil => simp at hr
    | cons q es =>
      simp only [List.map_cons, List.cons.injEq] at hr
      obtain ⟨hr1, hr2⟩ := hr
      have hx' : ∀ a ∈ p :: ds, a.1.eval σ < a.2.eval σ := hx
      have hy' : ∀ a ∈ q :: es, a.1.eval τ < a.2.eval τ := hy
      have hp := hx' p List.mem_cons_self
      have hq := hy' q List.mem_cons_self
      rw [← hr1] at hq
      have ih' := ih (fun a ha => hx' a (List.mem_cons_of_mem p ha)) es
        (fun a ha => hy' a (List.mem_cons_of_mem q ha)) hr2
      simp only [val, digitVals, List.foldr_cons, List.map_cons, List.cons.injEq] at ih' ⊢
      rw [← hr1, add_mul_eq_iff hp hq, ih']

/-- **Horner's rule split at a digit**: for every digit lists `a`, `b` and size assignment `σ`, the
value of the digits `a` then `b` is the value of `a` plus the radix product of `a` times the
value of `b`. -/
theorem val_append (a b : List (SizeExpr × SizeExpr)) (σ : Sizes) :
    val ⟨a ++ b⟩ σ = val ⟨a⟩ σ + radixProd ⟨a⟩ σ * val ⟨b⟩ σ := by
  induction a with
  | nil => simp [val, radixProd]
  | cons p a ih =>
    simp only [val, radixProd, List.cons_append, List.foldr_cons, List.map_cons,
      List.prod_cons] at ih ⊢
    rw [ih, Nat.mul_add, Nat.mul_assoc, Nat.add_assoc]

end MixedRadix

/-- **What a width of `w` bits keeps of the index `k`**, for every width and number: the `w`-bit
word of `k` has the unsigned value `k` (truncation to `w` bits keeps `k`) and the signed value
`k`; its sign extension to every width `v` is the `v`-bit word of `k`; and for every `a + b = k`,
the add of the `w`-bit words of `a` and `b` overflows neither unsigned nor signed and gives the
word of `k`. -/
structure WordFit (w k : Nat) : Prop where
  /-- `WordFit w k` from its four fields. -/
  mk ::
  /-- The unsigned value of the `w`-bit word of `k` is `k`. -/
  toNat : (BitVec.ofNat w k).toNat = k
  /-- The signed value of the `w`-bit word of `k` is `k`. -/
  toInt : (BitVec.ofNat w k).toInt = k
  /-- Sign extension of the `w`-bit word of `k` to every width is the word of `k` there. -/
  signExtend : ∀ v, (BitVec.ofNat w k).signExtend v = BitVec.ofNat v k
  /-- The add of the words of two parts of `k` overflows neither way and gives the word of `k`. -/
  add : ∀ a b, a + b = k → (BitVec.ofNat w a).uaddOverflow (BitVec.ofNat w b) = false ∧
    (BitVec.ofNat w a).saddOverflow (BitVec.ofNat w b) = false ∧
    BitVec.ofNat w a + BitVec.ofNat w b = BitVec.ofNat w k

/-- `2 k < 2 ^ w` exactly when `k < 2 ^ (w - 1)`, for every width and number (both say `k = 0`
at `w = 0`). -/
theorem WordFit.two_mul_lt_iff {w k : Nat} : 2 * k < 2 ^ w ↔ k < 2 ^ (w - 1) := by
  rcases w with _ | w
  · simp only [Nat.pow_zero, Nat.zero_sub]
    omega
  · rw [Nat.pow_succ, Nat.add_sub_cancel]
    omega

/-- **Below `2 ^ (w - 1)`, the index fits `w` bits** (`WordFit`), for every width and number. -/
theorem WordFit.of_lt {w k : Nat} (h : k < 2 ^ (w - 1)) : WordFit w k := by
  -- the word of `j` with `2 j < 2 ^ w` has the signed value `j`: its sign bit is clear
  have toInt_ofNat : ∀ j, 2 * j < 2 ^ w → (BitVec.ofNat w j).toInt = j := fun j hj => by
    rw [BitVec.toInt_eq_toNat_cond, BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega)]
    simp [hj]
  have h2 : 2 * k < 2 ^ w := two_mul_lt_iff.2 h
  have hk : k < 2 ^ w := by omega
  refine ⟨by rw [BitVec.toNat_ofNat, Nat.mod_eq_of_lt hk], toInt_ofNat k h2, fun v => ?_,
    fun a b hab => ?_⟩
  · rw [BitVec.signExtend_eq_setWidth_of_msb_false]
    · apply BitVec.eq_of_toNat_eq
      simp [BitVec.toNat_setWidth, Nat.mod_eq_of_lt hk]
    · rw [BitVec.msb_eq_decide, BitVec.toNat_ofNat, Nat.mod_eq_of_lt hk]
      simpa using h
  · subst hab
    have ha : 2 * a < 2 ^ w := by omega
    have hb : 2 * b < 2 ^ w := by omega
    refine ⟨?_, ?_, BitVec.ofNat_add_ofNat a b⟩
    · simp only [BitVec.uaddOverflow, BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega : a < 2 ^ w),
        Nat.mod_eq_of_lt (by omega : b < 2 ^ w), decide_eq_false_iff_not]
      omega
    · simp only [BitVec.saddOverflow, toInt_ofNat a ha, toInt_ofNat b hb, Bool.or_eq_false_iff,
        decide_eq_false_iff_not]
      have hI : (a : Int) + b < 2 ^ (w - 1) := by exact_mod_cast h
      have hP : (0 : Int) ≤ 2 ^ (w - 1) := by exact_mod_cast Nat.zero_le (2 ^ (w - 1))
      constructor <;> omega

/-- **An index in range whose radix product is below `2 ^ (w - 1)` fits `w` bits** (`WordFit`):
sign extension, truncation and non-wrapping adds at width `w` keep it, for every size assignment,
radix list and width. -/
theorem MixedRadix.fits {x : MixedRadix} {σ : Sizes} {w : Nat} (hx : x.InRange σ)
    (h : x.radixProd σ < 2 ^ (w - 1)) : WordFit w (x.val σ) :=
  WordFit.of_lt (Nat.lt_trans (MixedRadix.lt_prod hx) h)

end GPUProof
