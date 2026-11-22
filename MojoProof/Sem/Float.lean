import MojoProof.LLVM.Syntax
import FloatLib.Floats.Formats.BinaryInterchange.Arithmetic.Runtime
import FloatLib.Floats.Formats.BinaryInterchange.Algebraic.RootProof
import FloatLib.Floats.Formats.BinaryInterchange.Operations.Runtime
import FloatLib.Floats.Formats.BinaryInterchange.Conversion.Cast.Runtime
import FloatLib.Floats.Formats.BinaryInterchange.DirectedSemantics.Rational.Conversion
import FloatLib.Floats.Formats.BinaryInterchange.Format.Catalog
import FloatLib.Floats.Formats.BinaryInterchange.Analysis.Error
import FloatLib.Floats.Formats.BinaryInterchange.Operations.Classification.Semantics
import Mathlib.Analysis.SpecialFunctions.Pow.Real

/-!
# Floating-point operations

The floating-point layer of the semantics. A value of float type `t` is a word of
`t.fmt.bitWidth` bits read as a FloatLib `Model t.fmt` (`FloatTy.fmt`: `half` is binary16,
`bfloat` bfloat16, `float` binary32, `double` binary64), and every operation is FloatLib's
round-to-nearest-even operation on that format. There is no other float model.

LLVM's freedoms are functions of an oracle number `n`; the semantics quantifies over the oracle.

* NaN results (`deliver`): where IEEE 754 returns a NaN, LLVM returns a NaN from a set it defines
  (LangRef, "Behavior of Floating-Point NaN values"); the semantics returns any NaN, a superset
  (TRUST T7).
* Contraction (`contract`): an `fadd contract` / `fsub contract` with an operand that an
  `fmul contract` computed may be one fused multiply-add (LangRef, "Fast-Math Flags": "Allow
  floating-point contraction (e.g., fusing a multiply followed by an addition into a fused
  multiply-and-add)").
* `llvm.maxnum` / `llvm.minnum` (`maxnum`): LangRef's rules, with its choices for signaling
  NaNs; `-0` is below `+0` (`nsz`, which would allow either, is refused).
* `llvm.nvvm.rsqrt.approx.ftz.f` (`rsqrt`): any word that meets the contract of PTX's
  `rsqrt.approx.ftz.f32` (`rsqrtOk`: PTX ISA 9.5, section 9.7.3.16), with subnormal operands
  flushed. Its relative error bound is the rational `rsqrtErr`, at least PTX's `2 ^ -22.9`.

Proved here, for all operands: `deliver` returns `r` when `r` is not a NaN
(`deliver_of_isNaN_eq_false`), and otherwise returns a NaN (`isNaN_deliver`) and can return every
NaN (`exists_deliver`); a contracted result is the unfused result or a fused multiply-add
(`contract_cases`) and, when finite and its operands are rounded products of their factors
(`IsProd`), is within the roundoff bound of the choice made of the exact sum of the products
(`contract_error`, every IEEE format); `2 ^ -22.9 ≤ rsqrtErr` (`rpow_le_rsqrtErr`); for a
positive operand, the rational test `rsqrtNear` is the relative error bound over the reals
(`rsqrtNear_iff`); for every binary32 `x`, FloatLib's reciprocal square root `Model.rSqrt` of
`x` with subnormals flushed, the fallback of `rsqrt`, meets the contract (`rsqrtOk_rSqrt`), so
every value of `rsqrt` meets it (`rsqrtOk_of_rsqrt`), and every word that meets it is a value
(`rsqrt_toNatBits`).
-/

namespace MojoProof.LLVM

open FloatLib.Floats.Formats.BinaryInterchange

/-- The FloatLib format of a float type. -/
def FloatTy.fmt : FloatTy → FloatFormat
  | .half => .binary16
  | .bfloat => .bfloat16
  | .float => .binary32
  | .double => .binary64

/-- The predicate of `fcmp p` on the IEEE comparison `c` (`none`: unordered, a NaN operand). -/
def FCmp.holds (p : FCmp) (c : Option _root_.Ordering) : Bool :=
  let (onNaN, onCmp) : Bool × (_root_.Ordering → Bool) := match p with
    | .false => (Bool.false, fun _ => Bool.false)
    | .oeq => (Bool.false, (· == .eq))
    | .ogt => (Bool.false, (· == .gt))
    | .oge => (Bool.false, (· != .lt))
    | .olt => (Bool.false, (· == .lt))
    | .ole => (Bool.false, (· != .gt))
    | .one => (Bool.false, (· != .eq))
    | .ord => (Bool.false, fun _ => Bool.true)
    | .ueq => (Bool.true, (· == .eq))
    | .ugt => (Bool.true, (· == .gt))
    | .uge => (Bool.true, (· != .lt))
    | .ult => (Bool.true, (· == .lt))
    | .ule => (Bool.true, (· != .gt))
    | .une => (Bool.true, (· != .eq))
    | .uno => (Bool.true, fun _ => Bool.false)
    | .true => (Bool.true, fun _ => Bool.true)
  match c with
  | none => onNaN
  | some o => onCmp o

end MojoProof.LLVM

namespace MojoProof.Sem

open FloatLib FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange LLVM

variable {fmt : FloatFormat}

/-- The value an operation delivers when its IEEE 754 result is `r` and the oracle offers `n`:
`r` unless `r` is a NaN, and otherwise the NaN with bits `n` (`r` if `n` encodes no NaN). -/
def deliver (r : Model fmt) (n : Nat) : Model fmt :=
  if r.isNaN then (if (Model.ofNatBits n : Model fmt).isNaN then Model.ofNatBits n else r) else r

/-- An operation whose result is not a NaN delivers that result, for every oracle number. -/
theorem deliver_of_isNaN_eq_false {r : Model fmt} (h : r.isNaN = false) (n : Nat) :
    deliver r n = r := by
  simp [deliver, h]

/-- An operation whose result is a NaN delivers a NaN, for every oracle number. -/
theorem isNaN_deliver {r : Model fmt} (h : r.isNaN = true) (n : Nat) :
    (deliver r n).isNaN = true := by
  unfold deliver
  split <;> [split <;> assumption; simp_all]

/-- Every NaN is a possible result of an operation whose IEEE 754 result is a NaN. -/
theorem exists_deliver {r x : Model fmt} (h : r.isNaN = true) (hx : x.isNaN = true) :
    ∃ n, deliver r n = x :=
  ⟨x.toNatBits, by simp [deliver, h, hx]⟩

/-- `fadd contract` (`sub = false`) or `fsub contract` of `x` and `y`, where `px` / `py` are the
factors of `x` / `y` when an `fmul contract` computed it. The oracle number `n` selects the
separately rounded operation, the fused `fma a b (±y)` for `x = a * b`, or the fused
`fma (±c) d x` for `y = c * d`. The result goes through `deliver` like any other. -/
def contract (sub : Bool) (x y : Model fmt) (px py : Option (Model fmt × Model fmt)) (n : Nat) :
    Model fmt :=
  match n % 3, px, py with
  | 1, some (a, b), _ => Model.fma a b (if sub then Model.neg y else y)
  | 2, _, some (c, d) => Model.fma (if sub then Model.neg c else c) d x
  | _, _, _ => if sub then Model.sub x y else Model.add x y

/-- A contracted result is the separately rounded one or a fused multiply-add of one of the
products. -/
theorem contract_cases (sub : Bool) (x y : Model fmt) (px py : Option (Model fmt × Model fmt))
    (n : Nat) :
    contract sub x y px py n = (if sub then Model.sub x y else Model.add x y) ∨
      (∃ a b, px = some (a, b) ∧
        contract sub x y px py n = Model.fma a b (if sub then Model.neg y else y)) ∨
      (∃ c d, py = some (c, d) ∧
        contract sub x y px py n = Model.fma (if sub then Model.neg c else c) d x) := by
  unfold contract
  split
  · exact .inr (.inl ⟨_, _, rfl, rfl⟩)
  · exact .inr (.inr ⟨_, _, rfl, rfl⟩)
  · exact .inl rfl

/-- The exact value an operand of a contracted operation stands for: the real product of its
`fmul contract` factors `p` if it has them, else its own real value. -/
noncomputable def exact (x : Model fmt) : Option (Model fmt × Model fmt) → ℝ
  | some (a, b) => a.toReal * b.toReal
  | none => x.toReal

/-- The rounding error of the product of factors `p`: half an ULP at it, or `0` without factors. -/
noncomputable def factorErr : Option (Model fmt × Model fmt) → ℝ
  | some (a, b) => Model.halfUlpAt fmt (a.toReal * b.toReal)
  | none => 0

/-- `x` is a rounded product of factors `p`, as far as its real value goes: if `x` is finite, so is
`Model.mul a b`, with the same real value. Every `fmul` result is one, whatever its flags and
oracle (`MojoProof.Sem.isProd_withFlags`): only a NaN may change. -/
def IsProd (x : Model fmt) (p : Option (Model fmt × Model fmt)) : Prop :=
  ∀ a b, p = some (a, b) → x.isFinite = true →
    (Model.mul a b).isFinite = true ∧ x.toReal = (Model.mul a b).toReal

/-- In an IEEE format, a finite rounded product `x` of factors `p` (`IsProd`) is within
`factorErr p` (half an ULP at the product) of the exact value it stands for (`exact x p`). -/
theorem abs_sub_exact_le (hfmt : fmt.isIEEE = true) {x : Model fmt}
    {p : Option (Model fmt × Model fmt)} (hp : IsProd x p) (hx : x.isFinite = true) :
    |x.toReal - exact x p| ≤ factorErr p := by
  match p, hp with
  | some (a, b), hp =>
    obtain ⟨hm, he⟩ := hp a b rfl hx
    rw [he]
    exact Model.abs_toReal_mul_sub_le a b hfmt hm
  | none, _ => simp [exact, factorErr]

/-- A contracted `x + y` (`x - y` if `sub`) with a finite result, fused or not, where `x` and `y`
are rounded products of their `fmul contract` factors `px`, `py` when they have them (`IsProd`),
is within the roundoff bound of the choice made of the exact `exact x px ± exact y py`: unfused,
the factors' rounding errors plus half an ULP at the rounded sum; fused with `x`'s factors, `y`'s
rounding error plus half an ULP at the fused sum; fused with `y`'s, symmetrically. For every IEEE
format, all operands and every oracle number. -/
theorem contract_error (hfmt : fmt.isIEEE = true) (sub : Bool) {x y : Model fmt}
    {px py : Option (Model fmt × Model fmt)} (hx : IsProd x px) (hy : IsProd y py) (n : Nat)
    (h : (contract sub x y px py n).isFinite = true) :
    let s : ℝ := if sub then -1 else 1
    |(contract sub x y px py n).toReal - (exact x px + s * exact y py)| ≤
      max (factorErr px + factorErr py + Model.halfUlpAt fmt (x.toReal + s * y.toReal))
        (max (factorErr py + Model.halfUlpAt fmt (exact x px + s * y.toReal))
          (factorErr px + Model.halfUlpAt fmt (x.toReal + s * exact y py))) := by
  intro s
  rcases contract_cases sub x y px py n with hr | ⟨a, b, rfl, hr⟩ | ⟨c, d, rfl, hr⟩ <;>
    rw [hr] at h ⊢
  · have ⟨fx, fy, e⟩ : x.isFinite = true ∧ y.isFinite = true ∧
        |(if sub then Model.sub x y else Model.add x y).toReal - (x.toReal + s * y.toReal)| ≤
          Model.halfUlpAt fmt (x.toReal + s * y.toReal) := by
      cases sub
      · obtain ⟨fx, fy⟩ := Model.isFinite_of_isFinite_add hfmt h
        exact ⟨fx, fy, by simpa [s] using Model.abs_toReal_add_sub_le x y hfmt h⟩
      · obtain ⟨fx, fy⟩ := Model.isFinite_of_isFinite_sub hfmt h
        exact ⟨fx, fy, by simpa [s, sub_eq_add_neg] using Model.abs_toReal_sub_sub_le x y hfmt h⟩
    have ex := abs_le.1 (abs_sub_exact_le hfmt hx fx)
    have ey := abs_le.1 (abs_sub_exact_le hfmt hy fy)
    have e := abs_le.1 e
    refine le_trans ?_ (le_max_left _ _)
    rw [abs_le]
    constructor <;> cases sub <;> simp only [s, Bool.false_eq_true, ↓reduceIte] at * <;> linarith
  · obtain ⟨-, -, fy⟩ := Model.isFinite_of_isFinite_fma hfmt h
    have fy' : y.isFinite = true := by cases sub <;> simpa using fy
    have e := Model.abs_toReal_fma_sub_le a b _ hfmt h
    have ey := abs_le.1 (abs_sub_exact_le hfmt hy fy')
    have e' : |(Model.fma a b (if sub then Model.neg y else y)).toReal -
        (exact x (some (a, b)) + s * y.toReal)| ≤ Model.halfUlpAt fmt
          (exact x (some (a, b)) + s * y.toReal) := by
      cases sub <;> simpa [s, exact, Model.toReal_neg y fy', sub_eq_add_neg] using e
    have e' := abs_le.1 e'
    refine le_trans ?_ ((le_max_left _ _).trans (le_max_right _ _))
    rw [abs_le]
    constructor <;> cases sub <;> simp only [s, Bool.false_eq_true, ↓reduceIte] at * <;> linarith
  · obtain ⟨fc, -, fx⟩ := Model.isFinite_of_isFinite_fma hfmt h
    have fc' : c.isFinite = true := by cases sub <;> simpa using fc
    have e := Model.abs_toReal_fma_sub_le _ d x hfmt h
    have ex := abs_le.1 (abs_sub_exact_le hfmt hx fx)
    have e' : |(Model.fma (if sub then Model.neg c else c) d x).toReal -
        (x.toReal + s * exact y (some (c, d)))| ≤ Model.halfUlpAt fmt
          (x.toReal + s * exact y (some (c, d))) := by
      have : ((if sub then Model.neg c else c).toReal * d.toReal + x.toReal) =
          x.toReal + s * exact y (some (c, d)) := by
        cases sub <;> simp [s, exact, Model.toReal_neg c fc'] <;> ring
      rwa [this] at e
    have e' := abs_le.1 e'
    refine le_trans ?_ ((le_max_right _ _).trans (le_max_right _ _))
    rw [abs_le]
    constructor <;> cases sub <;> simp only [s, Bool.false_eq_true, ↓reduceIte] at * <;> linarith

/-- `llvm.maxnum` (`max`) or `llvm.minnum` of `x` and `y`, given the oracle number `n` (LangRef,
"'llvm.maxnum.*' Intrinsic"): with a signaling NaN operand, any NaN or the result for a quiet one;
otherwise IEEE 754-2019 `maximumNumber` / `minimumNumber`, which return the number when one
operand is a NaN and order `-0` below `+0`, as PTX's `max` / `min` do (PTX ISA 9.5, sections
9.7.3.11-12: "+0.0 > -0.0"). A NaN result is any NaN (`deliver`). Under `nsz` LangRef lets zeros of
opposite signs give either operand; the semantics refuses `nsz` (`FastMath.check`). -/
def maxnum (max : Bool) (x y : Model fmt) (n : Nat) : Model fmt :=
  if (x.isSignaling || y.isSignaling) && n % 2 == 1 then deliver (Model.canonicalNaN fmt) (n / 2)
  else deliver (if max then Model.maximumNumber x y else Model.minimumNumber x y) (n / 2)

/-- The relative error of the `rsqrt.approx.ftz.f32` contract, `1.0718 * 2 ^ -23`: a rational at
least PTX's `2 ^ -22.9` (`rpow_le_rsqrtErr`). -/
def rsqrtErr : ℚ := 10718 / 10000 / 2 ^ 23

/-- PTX's relative error bound `2 ^ -22.9` for `rsqrt.approx.ftz.f32` is at most `rsqrtErr`. -/
theorem rpow_le_rsqrtErr : (2 : ℝ) ^ (-22.9 : ℝ) ≤ rsqrtErr := by
  have e0 : (0 : ℝ) ≤ rsqrtErr := by norm_num [rsqrtErr]
  rw [← pow_le_pow_iff_left₀ (by positivity) e0 (by norm_num : (10 : ℕ) ≠ 0),
    ← Real.rpow_natCast, ← Real.rpow_mul (by norm_num),
    show (-22.9 : ℝ) * (10 : ℕ) = -((229 : ℕ) : ℝ) by norm_num, Real.rpow_neg (by norm_num),
    Real.rpow_natCast]
  norm_num [rsqrtErr]

/-- `b` is within relative error `rsqrtErr` of `1 / sqrt a`, in rationals (`rsqrtNear_iff`):
`0 ≤ b` and `(1 - rsqrtErr)² ≤ b² a ≤ (1 + rsqrtErr)²`. -/
def rsqrtNear (a b : ℚ) : Bool :=
  0 ≤ b && (1 - rsqrtErr) ^ 2 ≤ b * b * a && b * b * a ≤ (1 + rsqrtErr) ^ 2

/-- For a positive rational `a`: `rsqrtNear a b` holds exactly when `b` is within relative error
`rsqrtErr` of `1 / √a`, in the reals. -/
theorem rsqrtNear_iff {a b : ℚ} (ha : 0 < a) :
    rsqrtNear a b = true ↔ |(b : ℝ) - 1 / √(a : ℝ)| ≤ rsqrtErr / √(a : ℝ) := by
  have ha' : (0 : ℝ) < a := by exact_mod_cast ha
  have s0 : 0 < √(a : ℝ) := Real.sqrt_pos.2 ha'
  have sq : (b : ℝ) * b * a = (b * √(a : ℝ)) ^ 2 := by rw [mul_pow, Real.sq_sqrt ha'.le]; ring
  have e0 : (0 : ℝ) ≤ rsqrtErr := by norm_num [rsqrtErr]
  have e1 : (0 : ℝ) ≤ 1 - rsqrtErr := by norm_num [rsqrtErr]
  rw [show (b : ℝ) - 1 / √(a : ℝ) = (b * √(a : ℝ) - 1) / √(a : ℝ) by field_simp, abs_div,
    abs_of_pos s0, div_le_div_iff_of_pos_right s0, abs_le]
  simp only [rsqrtNear, Bool.and_eq_true, decide_eq_true_eq, ← Rat.cast_le (K := ℝ)]
  push_cast
  rw [sq]
  constructor
  · rintro ⟨⟨hb, h1⟩, h2⟩
    have t0 : 0 ≤ (b : ℝ) * √(a : ℝ) := mul_nonneg hb s0.le
    have := (pow_le_pow_iff_left₀ e1 t0 two_ne_zero).1 h1
    have := (pow_le_pow_iff_left₀ t0 (by linarith) two_ne_zero).1 h2
    constructor <;> linarith
  · rintro ⟨h1, h2⟩
    have t0 : 0 ≤ (b : ℝ) * √(a : ℝ) := by linarith
    have hb : (0 : ℝ) ≤ b := by
      by_contra hn
      linarith [mul_neg_of_neg_of_pos (not_le.1 hn) s0]
    exact ⟨⟨hb, pow_le_pow_left₀ e1 (by linarith) 2⟩, pow_le_pow_left₀ t0 (by linarith) 2⟩

/-- Word `w` meets the contract of `rsqrt.approx.ftz.f32` on operand `x` (PTX ISA 9.5, section
9.7.3.16: "Compute 1/sqrt(a)"; its table of special inputs; "The maximum relative error for
rsqrt.f32 over the entire positive finite floating-point range is 2-22.9"; `.ftz` "flushes
subnormal inputs and results to sign-preserving zero"). A subnormal `x` counts as a zero of its
sign. A NaN or negative `x` (`-∞` included) gives a NaN, `-0` gives `-∞`, `+0` gives `+∞`, `+∞`
gives `+0`, and a positive finite `x` a `w` that is not subnormal and within relative error
`rsqrtErr` of `1 / sqrt x` (`rsqrtNear`). -/
def rsqrtOk (x w : Model .binary32) : Bool :=
  if x.isNaN then w.isNaN
  else if x.isZero || x.isSubnormal then
    w == if x.signBit then Model.negInf .binary32 else Model.posInf .binary32
  else if x.signBit then w.isNaN
  else if x.isInfinite then w == Model.posZero .binary32
  else match x.toRat?, w.toRat? with
    | some a, some b => !w.isSubnormal && rsqrtNear a b
    | _, _ => false

/-- `rsqrt.approx.ftz.f32` of `x` with oracle number `n`: the word `n` if it meets the contract
(`rsqrtOk`), else FloatLib's reciprocal square root `Model.rSqrt` of `x`, with a subnormal `x`
flushed to the zero of its sign, which meets it for every `x` (`rsqrtOk_rSqrt`). Its values are
exactly the words that meet the contract (`rsqrtOk_of_rsqrt`, `rsqrt_toNatBits`). -/
def rsqrt (x : Model .binary32) (n : Nat) : Model .binary32 :=
  let w := Model.ofNatBits n
  let x' := if x.isSubnormal then (if x.signBit then Model.negZero _ else Model.posZero _) else x
  if rsqrtOk x w then w else Model.rSqrt x'

/-- For every binary32 word `w` that meets the contract on `x`, `rsqrt` gives `w` under the
oracle number of its bits. -/
theorem rsqrt_toNatBits {x w : Model .binary32} (h : rsqrtOk x w = true) :
    rsqrt x w.toNatBits = w := by
  simp [rsqrt, h]

-- Mathlib v4.36.0 exposes `Real`'s operations to files outside the module system, so elaborating
-- hypotheses about concrete reals unfolds their arithmetic, which needs a deeper recursion limit.
set_option maxRecDepth 4096 in
/-- For every binary32 `x`, FloatLib's reciprocal square root `Model.rSqrt` of `x`, with a
subnormal `x` flushed to the zero of its sign, meets the contract: a NaN gives a quiet NaN, a zero
or flushed subnormal the infinity of its sign, a negative nonzero `x` (`-∞` included) the
canonical NaN, `+∞` gives `+0`, and a positive normal `x` the one rounding of `1 / sqrt x`
(FloatLib's `toReal_rSqrt_eq_roundAt`), which is finite since `1 / sqrt x ≤ 2 ^ 63`, is normal,
and is within relative error `2 ^ -24` of `1 / sqrt x`, under `rsqrtErr`. -/
theorem rsqrtOk_rSqrt (x : Model .binary32) :
    rsqrtOk x (Model.rSqrt (if x.isSubnormal then
      (if x.signBit then Model.negZero _ else Model.posZero _) else x)) = true := by
  have hfmt : FloatFormat.binary32.isIEEE = true := rfl
  unfold rsqrtOk
  by_cases hsub : x.isSubnormal = true
  · -- `x` is flushed to the zero of its sign, whose reciprocal square root is that sign's
    -- infinity.
    have hn : x.isNaN = false :=
      Model.isNaN_eq_false_of_isFinite_eq_true x (Model.isFinite_of_isSubnormal hsub)
    have hz : ∀ s : Bool,
        (if s then Model.negZero FloatFormat.binary32 else Model.posZero _).isZero = true := by
      intro s
      cases s
      · exact Model.isZero_posZero _
      · exact Model.isZero_negZero _ rfl
    rw [ite_eq_left hsub, Model.rSqrt_of_isZero _ (hz _),
      Model.nativeOverflow_eq_signedInf_of_isIEEE _ hfmt]
    cases hs : x.signBit <;> simp [hn, hsub]
  rw [ite_eq_right hsub]
  replace hsub : x.isSubnormal = false := by simpa using hsub
  by_cases hn : x.isNaN = true
  · simp [hn, Model.rSqrt, Model.chooseNaN1]
  replace hn : x.isNaN = false := by simpa using hn
  have hc : Model.chooseNaN1 x = none := by simp [Model.chooseNaN1, hn]
  by_cases hz : x.isZero = true
  · rw [Model.rSqrt_of_isZero x hz, Model.nativeOverflow_eq_signedInf_of_isIEEE _ hfmt]
    simp [hn, hz]
  replace hz : x.isZero = false := by simpa using hz
  by_cases hp : x.signBit = true
  · have h : Model.rSqrt x = Model.invalidResult _ := by simp [Model.rSqrt, hc, hz, hp]
    have hnan : (Model.canonicalNaN FloatFormat.binary32).isNaN = true :=
      Model.isNaN_canonicalNaN rfl
    rw [h]
    simpa [hn, hz, hsub, hp] using hnan
  replace hp : x.signBit = false := by simpa using hp
  by_cases hi : x.isInfinite = true
  · have h : Model.rSqrt x = Model.posZero _ := by simp [Model.rSqrt, hc, hz, hp, hi]
    rw [h]
    simp [hn, hz, hsub, hp, hi]
  replace hi : x.isInfinite = false := by simpa using hi
  -- `x` is a positive normal number `r = a`.
  have hf := Model.isFinite_eq_true_of_isNaN_eq_false_of_isInfinite_eq_false x hn hi
  obtain ⟨a, ha⟩ : ∃ a, x.toRat? = some a :=
    Option.isSome_iff_exists.1 (by rw [Model.Algebraic.toRat?_isSome_eq_isFinite]; exact hf)
  have b2 : ∀ e : ℤ, Flocq.bpow Numerics.binaryRadix e = (2 : ℝ) ^ e := by
    intro e; simp [Flocq.bpow, Numerics.binaryRadix, Numerics.Radix.toReal]
  have hu : Flocq.bpow Numerics.binaryRadix
      (1 - Int.ofNat (FloatFormat.binary32.fracWidth + 1)) / 2 = 1 / 2 ^ 24 := by
    rw [b2]; norm_num [FloatFormat.binary32]
  have hmine : FloatFormat.binary32.minNormalExponent = -126 := by decide
  have hmin : Model.minNormalAt FloatFormat.binary32 = 1 / 2 ^ 126 := by
    rw [Model.minNormalAt, b2, hmine]; norm_num
  have relE : ∀ y : ℝ, 0 < y → 1 / 2 ^ 126 ≤ y →
      |Model.roundAt FloatFormat.binary32 y - y| ≤ 1 / 2 ^ 24 * y := by
    intro y y0 hy
    have := Model.relativeError_roundAt_le_of_normal FloatFormat.binary32 y y0.ne'
      (by rw [hmin, abs_of_pos y0]; exact hy)
    rw [hu, Flocq.ErrorBounds.relativeError, abs_of_pos y0,
      div_le_iff₀ y0] at this
    exact this
  set r := x.toReal with hr
  have har : (a : ℝ) = r := (Model.Algebraic.toReal_of_toRat?_eq_some ha).symm
  have r0 : 0 < r := by
    have h0 := Model.toReal_nonneg_of_signBit_eq_false hp
    have h1 : r ≠ 0 := fun h => by
      have := (Model.isZero_eq_true_iff_toReal_eq_zero x hf).2 h
      simp_all
    exact lt_of_le_of_ne h0 (Ne.symm h1)
  have rlo : 1 / 2 ^ 126 ≤ r := by
    by_contra hlt
    have := (Model.isSubnormal_iff_abs_toReal x).2 ⟨hf, by rw [abs_of_pos r0]; exact r0,
      by rw [abs_of_pos r0, hmine]; norm_num at hlt ⊢; linarith⟩
    simp_all
  have rhi : r ≤ 2 ^ 128 := by
    have h1 := Model.abs_toReal_le_posMaxFinite_of_isFinite x hf
    have h2 := Model.toReal_posMaxFinite_lt_bpow FloatFormat.binary32
    have e1 : FloatFormat.binary32.maxNormalExponent + 1 = 128 := by decide
    rw [Model.bpow, b2, e1] at h2
    rw [abs_of_pos r0] at h1
    norm_num at h2 ⊢; linarith
  -- `σ = √r` and the target `t = 1 / σ`.
  set σ := Real.sqrt r with hσ
  have σ0 : 0 < σ := Real.sqrt_pos.2 r0
  have σsq : σ * σ = r := Real.mul_self_sqrt r0.le
  have σlo : 1 / 2 ^ 63 ≤ σ := by
    by_contra h
    have := mul_self_lt_mul_self σ0.le (not_le.1 h)
    norm_num at this rlo; linarith
  have σhi : σ ≤ 2 ^ 64 := by
    by_contra h
    have := mul_self_lt_mul_self (by norm_num) (not_le.1 h)
    norm_num at this rhi; linarith
  set t := σ⁻¹ with ht
  have t0 : 0 < t := inv_pos.2 σ0
  have tσ : t * σ = 1 := inv_mul_cancel₀ σ0.ne'
  have tlo : 1 / 2 ^ 64 ≤ t := by nlinarith [mul_le_mul_of_nonneg_left σhi t0.le]
  have thi : t ≤ 2 ^ 63 := by nlinarith [mul_le_mul_of_nonneg_left σlo t0.le]
  -- `Model.rSqrt x` rounds `t` once, the exact comparator of `√(1 / a)`, and is finite.
  have heq : Model.rSqrt x = Model.AlgebraicRounding.round .binary32 false
      (Posit.Model.RootRounding.compareRoot a⁻¹ 2) := by
    rw [show Model.rSqrt x = Model.AlgebraicRounding.sqrtRat .binary32 false a⁻¹ by
      simp [Model.rSqrt, hc, hz, hp, hi, ha], Model.AlgebraicRounding.sqrtRat_eq_root]
    rfl
  have hroot : t ^ 2 = ((a⁻¹ : ℚ) : ℝ) := by
    rw [Rat.cast_inv, har, ht, inv_pow, hσ, Real.sq_sqrt r0.le]
  have hcmp := Posit.Model.RootRounding.compareRoot_eq_real a⁻¹ 2 t t0.le (by decide) hroot
  have hupE : Model.AlgebraicRounding.upperExponent FloatFormat.binary32 = 128 := by decide
  have hmaxE : Int.ofNat (FloatFormat.ieeeMaxNormalExponent FloatFormat.binary32) = 127 := by
    decide
  have hfin : (Model.rSqrt x).isFinite = true := by
    rw [heq, Model.AlgebraicRounding.round_eq _ false hcmp]
    split_ifs with h1 h2
    · exact Model.isFinite_eq_true_of_isZero_eq_true _ (Model.isZero_zero _ _)
    · refine absurd ?_ h2
      rw [hcmp, Model.AlgebraicRounding.cast_powerOfTwo, hupE, b2]
      exact (cmp_eq_lt_iff _ _).2
        (by linarith [show (2 : ℝ) ^ (63 : ℕ) < 2 ^ (128 : ℤ) by norm_num])
    · obtain ⟨hround, hacc, hexp⟩ :=
        Model.AlgebraicRounding.roundCertificate_certificate_spec _ hfmt false _ t hcmp
          (Model.AlgebraicRounding.bpow_lowerExponent_lt_of_compare_eq_gt _ hcmp
            (not_not.1 h1)).le
          (Model.AlgebraicRounding.lt_bpow_upperExponent_of_compare_eq_lt _ hcmp
            (not_not.1 h2))
      rw [hround]
      refine Model.isFinite_ofModel_roundWithAccuracy_of_lt_bpow _ hfmt _ _ _ _ _ hacc hexp ?_
      rw [div_mul_cancel₀ _ (Flocq.bpow.ne_zero _ _), b2, hmaxE]
      linarith [show (2 : ℝ) ^ (63 : ℕ) < 2 ^ (127 : ℤ) by norm_num]
  have hT := Model.toReal_rSqrt_eq_roundAt x hfmt hf hfin
  rw [← hr, ← hσ, ← ht] at hT
  set w := Model.rSqrt x with hw
  set T := w.toReal with hTdef
  have eT : |T - t| ≤ 1 / 2 ^ 24 * t := by
    rw [hT]
    exact relE t t0 (by linarith [show (1 : ℝ) / 2 ^ 126 ≤ 1 / 2 ^ 64 by norm_num])
  have eT' := abs_le.1 eT
  have key : |T - 1 / σ| ≤ (rsqrtErr : ℝ) / σ := by
    have e : (1 : ℝ) / 2 ^ 24 ≤ rsqrtErr := by norm_num [rsqrtErr]
    have e1 : 1 / σ = t := by rw [ht, one_div]
    have e2 : (rsqrtErr : ℝ) / σ = rsqrtErr * t := by rw [ht, div_eq_mul_inv]
    rw [e1, e2]
    exact eT.trans (mul_le_mul_of_nonneg_right e t0.le)
  -- The contract.
  obtain ⟨b, hb⟩ : ∃ b, w.toRat? = some b :=
    Option.isSome_iff_exists.1 (by rw [Model.Algebraic.toRat?_isSome_eq_isFinite]; exact hfin)
  have hbr : (b : ℝ) = T := (Model.Algebraic.toReal_of_toRat?_eq_some hb).symm
  have T0 : 0 < T := by linarith [eT'.1, show (0 : ℝ) < 1 / 2 ^ 64 by norm_num]
  have hwn : w.isSubnormal = false := by
    cases h : w.isSubnormal
    · rfl
    · have := ((Model.isSubnormal_iff_abs_toReal w).1 h).2.2
      rw [← hTdef, hmine, abs_of_pos T0] at this
      norm_num at this; linarith [eT'.1]
  simp only [hn, hz, hsub, hp, hi, Bool.or_false, Bool.false_eq_true, ↓reduceIte, ha, hb, hwn,
    Bool.not_false, Bool.true_and]
  rw [rsqrtNear_iff (by exact_mod_cast har ▸ r0), har, hbr]
  exact key

/-- For every binary32 operand and oracle number, the value of `rsqrt.approx.ftz.f32` meets the
contract: the oracle's word if it does, else the fallback, by `rsqrtOk_rSqrt`. -/
theorem rsqrtOk_of_rsqrt (x : Model .binary32) (n : Nat) : rsqrtOk x (rsqrt x n) = true := by
  simp only [rsqrt]
  split
  · assumption
  · exact rsqrtOk_rSqrt x

/-- The IEEE 754 operation (round to nearest even) of a float binary operator; `frem`, which is
C's `fmod` rather than IEEE `remainder`, has none. -/
def fbin : FBinOp → Option (Model fmt → Model fmt → Model fmt)
  | .fadd => some fun x y => Model.add x y
  | .fsub => some fun x y => Model.sub x y
  | .fmul => some fun x y => Model.mul x y
  | .fdiv => some fun x y => Model.div x y
  | .frem => none

end MojoProof.Sem
