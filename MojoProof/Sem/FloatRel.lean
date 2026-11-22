import MojoProof.Sem.Skeleton
import FloatLib.Floats.Formats.BinaryInterchange.Operations.Compare.Classification
import FloatLib.Floats.Formats.BinaryInterchange.Arithmetic.Proof
import FloatLib.Floats.Formats.BinaryInterchange.Arithmetic.SignedSemantics.Core
import FloatLib.Floats.Formats.BinaryInterchange.Dyadic.Classification
import FloatLib.Floats.Formats.BinaryInterchange.Spec.Division

/-!
# Relations between two runs' float results, one operation at a time (T5's rows)

The relations on float results that are proved, each for one operation on scalars (`Val`) or on
words, not for terms (docs/proofs/payload.md, section "T5's rows, one operation at a time").

Definitions, for every FloatLib format: `FinEq` (equal words, or neither finite), `NaNEq` (equal
words, or both NaNs), the estimate `Est` with its validity flag and `Est.Holds` (if valid, the word
is finite and within the bound of the value), `Est.contract` (the estimate of a contracted `fadd` /
`fsub`: the exact value of `contract_error`, its bound, valid when the operands are finite and no
choice's exact result exceeds the largest finite magnitude), and `RsqrtClose` (a binary32 word
finite and within relative error `rsqrtErr` of `1 / √a`). On scalars: `Val.Lift`, a relation on
the floats of one type as one on scalars (equal scalars, or two related floats);
`Respects R S C o`, an operation that gives related results (`Except.Rel S`: the same fault, or
values related by `S`) on operand lists related by `R` and oracle numbers coupled by `C`; and
`floatOp`, `floatBin` with no recorded factor on operand lists.

Proved, for all operands:
* `FinEq.deliver`: `deliver` keeps `FinEq` for every two oracle numbers (with `not_finite_deliver`);
  `FinEq.op`: so does every binary operation whose finite results have finite operands, which
  FloatLib's `add`, `sub` and `mul` are on every float type of the semantics (`fbin_finite`, with
  `isIEEE_fmt`).
* `floatBin_ofFloat`: on two floats of type `t`, with no recorded factor and flags without `nnan`,
  `ninf`, `nsz`, `reassoc`, `arcp`, `afn`, `floatBin` is FloatLib's operation through `deliver`, for
  every operator but `frem` and every oracle number (with `contract_none`: a contraction with no
  factor is the unfused operation); `floatBin_left` and `floatBin_right`: when one operand is not a
  float of type `t`, the result does not depend on the oracle number or on the other operand's
  float (with `Val.Lift.cases`).
* `floatOp_lift`: for every float type, relation `R` on its floats that relates each float to
  itself, operator with an IEEE operation `f` and flags without `nnan` and `ninf`, if `f` followed
  by `deliver` takes `R`-related operands to `R`-related results for every two oracle numbers,
  `floatOp` respects `Val.Lift t R` under any two oracle numbers.
* Row 1, `floatOp_finEq` (of `floatOp_lift`): for every float type, `fadd`, `fsub` and `fmul` with
  no recorded factor and flags without `nnan` and `ninf` respect `Val.Lift t FinEq` under any two
  oracle numbers.
* Row `rsqrt.approx`, `rsqrt_close`: for every positive binary32 `x` that is finite, not zero and
  not subnormal, `rsqrt x n` is `RsqrtClose` at `x.toReal`, for every oracle number; so two
  runs' results are both within relative error `rsqrtErr` of `1 / √x`, though they may differ.
* Row `maxnum` / `minnum`, on words: `maxnum_of_not_nan`, with no signaling NaN operand and not
  both operands NaNs, the result is FloatLib's `maximumNumber` or `minimumNumber` for every oracle
  number (free); `maxnum_nanEq`, for all operands, two oracle numbers of one parity give results
  related by `NaNEq` (coupled; with `NaNEq.deliver`, `deliver` keeps `NaNEq`). Its two runs have the
  same operands: the input relation is equality. It does not extend to `NaNEq` operands (a quiet
  and a signaling NaN with 1, under oracle number 1 in both runs, give 1 and a NaN).
* Row `maxnum` / `minnum`, at the intrinsic, on scalars: `intrinsic_fminmax_ofFloat`, the call of
  `llvm.maxnum` or `llvm.minnum` at a type whose element type is the float type `ft` on the scalars
  of two words `a` and `b` of `ft` returns, for every context, scope `s` and flags, the scalar of
  `maxnum` of `a` and `b` at `s`'s oracle number 0, or poison if the flags make it poison, and
  leaves `s`'s memory. Its corollaries: `fminmax_of_not_nan` (of `maxnum_of_not_nan`), with no
  signaling NaN operand and not both NaNs the result does not depend on the oracle number (free);
  `fminmax_nanEq` (of `maxnum_nanEq`), with flags without `nnan` and `ninf`, two scopes whose
  oracle numbers 0 have one parity give results related by `Val.Lift ft NaNEq` (coupled).
* Row `maxnum` / `minnum`, at the intrinsic, on vectors: `intrinsic_fminmax_vec`, for all lists of
  words `as` and `bs` of one length, the call on the vectors of their scalars returns, for every
  context, scope `s` and flags, the vector whose lane `j` is the scalar of `maxnum` of the lane's
  words at `s`'s oracle number `j` (or poison), and leaves `s`'s memory. Its corollaries:
  `fminmax_vec_of_not_nan`, with no lane having a signaling NaN operand or two NaN operands, the
  lanes are `maximumNumber` or `minimumNumber` of the lanes' words (free); `fminmax_vec_nanEq`,
  with flags without `nnan` and `ninf`, two scopes whose oracle numbers `j` have one parity at
  every lane `j` give vectors whose lanes are related by `Val.Lift ft NaNEq` (coupled lane by
  lane).
* The error relation's row, for one operation: `contract_est`, for every IEEE format, `sub`,
  operands that are rounded products of their factors (`IsProd`) and every oracle number, the
  contracted result meets `Est.contract` (valid: finite, by FloatLib's overflow bounds, and within
  `contract_error`'s bound of `exact a pa ± exact b pb`); `floatBin_contract_est`, for every float
  type, the float that `fadd` / `fsub` with `contract` (any other flags) gives on such operands
  meets it too (free; `holds_withFlags`: `deliver` and the flags keep a valid estimate).

* T5's NaN row: `fbin_isNaN`, for every format, `fadd`, `fsub`, `fmul` and `fdiv` give a NaN when
  an operand is a NaN (from FloatLib's equations of each operation with its specification, and
  `chooseNaN2`); `floatOp_isNaN`, so does `floatBin` with no recorded factor and flags without
  `nnan`, `ninf`, `nsz`, `reassoc`, `arcp` and `afn`, for every float type and oracle number
  (with `fbin_some`: every operator but `frem` has an IEEE operation).
* NaN equivalence under free oracles, `floatOp_nanEq` (of `floatOp_lift`, with `NaNEq.op`: every
  operator with an IEEE operation keeps `NaNEq`, by `fbin_isNaN`): for every float type, `fadd`,
  `fsub`, `fmul` and `fdiv` with no recorded factor and flags without `nnan` and `ninf` respect
  `Val.Lift t NaNEq` under any two oracle numbers.

Not proved: the error relation along terms (estimates of
operands that are themselves estimated results, with the bound and the validity flag
propagated); nor any statement about symbolic terms.
-/

namespace MojoProof.Sem

open FloatLib.Floats.Formats.BinaryInterchange LLVM

variable {fmt : FloatFormat}

/-- Equal words, or neither finite (each a NaN or an infinity). -/
def FinEq (x y : Model fmt) : Prop := x = y ∨ (x.isFinite = false ∧ y.isFinite = false)

/-- Equal words, or both NaNs. -/
def NaNEq (x y : Model fmt) : Prop := x = y ∨ (x.isNaN = true ∧ y.isNaN = true)

/-- An estimate of a float: a real value, an error bound, and whether the estimate applies (the
flag carries the range hypothesis: no exact result exceeds the largest finite magnitude). -/
structure Est where
  /-- Builds an estimate from its three fields. -/
  mk ::
  /-- The real value. -/
  value : ℝ
  /-- The error bound. -/
  bound : ℝ
  /-- Whether the estimate applies. -/
  valid : Bool

/-- Word `w` meets estimate `e`: if `e` is valid, `w` is finite and within `e.bound` of
`e.value`. -/
def Est.Holds (e : Est) (w : Model fmt) : Prop :=
  e.valid = true → w.isFinite = true ∧ |w.toReal - e.value| ≤ e.bound

/-- The binary32 word `w` is finite and within relative error `rsqrtErr` of `1 / √a`. -/
def RsqrtClose (a : ℝ) (w : Model .binary32) : Prop :=
  w.isFinite = true ∧ |w.toReal - 1 / √a| ≤ rsqrtErr / √a

/-- A relation on the floats of type `t` as one on scalars: equal scalars, or the scalars of two
related floats. -/
def Val.Lift (t : FloatTy) (R : Model t.fmt → Model t.fmt → Prop) (v v' : Val) : Prop :=
  v = v' ∨ ∃ a a', v = .ofFloat t a ∧ v' = .ofFloat t a' ∧ R a a'

/-- The operation `o` (operands and an oracle number to a result) respects `R` on operands and `S`
on results under the coupling `C` of oracle numbers: on operand lists related elementwise by `R`
and oracle numbers related by `C`, it gives the same fault or results related by `S`. -/
def Respects (R S : Val → Val → Prop) (C : Nat → Nat → Prop)
    (o : List Val → Nat → Except Fault Val) : Prop :=
  ∀ xs ys n n', List.Forall₂ R xs ys → C n n' → Except.Rel S (o xs n) (o ys n')

/-- `floatBin` with no recorded factor, as an operation on operand lists: a fault on a list whose
length is not 2. -/
def floatOp (t : FloatTy) (op : FBinOp) (fm : FastMath) : List Val → Nat → Except Fault Val
  | [x, y], n => floatBin t op fm x y none none n
  | _, _ => throw (.unsupported "float operation of the wrong arity")

/-- A word that is not finite is delivered as one that is not finite, for every oracle number. -/
theorem not_finite_deliver {r : Model fmt} (h : r.isFinite = false) (n : Nat) :
    (deliver r n).isFinite = false := by
  cases hr : r.isNaN
  · rw [deliver_of_isNaN_eq_false hr]
    exact h
  · exact Model.isFinite_eq_false_of_isNaN (isNaN_deliver hr n)

/-- `deliver` keeps `FinEq`, for every two oracle numbers: a NaN is delivered as a NaN, and a word
that is not a NaN as itself. -/
theorem FinEq.deliver {r r' : Model fmt} (h : FinEq r r') (n n' : Nat) :
    FinEq (deliver r n) (deliver r' n') := by
  rcases h with rfl | ⟨h1, h2⟩
  · cases hr : r.isNaN
    · exact .inl (by rw [deliver_of_isNaN_eq_false hr, deliver_of_isNaN_eq_false hr])
    · exact .inr ⟨Model.isFinite_eq_false_of_isNaN (isNaN_deliver hr n),
        Model.isFinite_eq_false_of_isNaN (isNaN_deliver hr n')⟩
  · exact .inr ⟨not_finite_deliver h1 n, not_finite_deliver h2 n'⟩

/-- `deliver` keeps `NaNEq`, for every two oracle numbers: a NaN is delivered as a NaN, and a word
that is not a NaN as itself. -/
theorem NaNEq.deliver {r r' : Model fmt} (h : NaNEq r r') (n n' : Nat) :
    NaNEq (deliver r n) (deliver r' n') := by
  rcases h with rfl | ⟨h1, h2⟩
  · cases hr : r.isNaN
    · exact .inl (by rw [deliver_of_isNaN_eq_false hr, deliver_of_isNaN_eq_false hr])
    · exact .inr ⟨isNaN_deliver hr n, isNaN_deliver hr n'⟩
  · exact .inr ⟨isNaN_deliver h1 n, isNaN_deliver h2 n'⟩

/-- Every binary operation whose finite results have finite operands keeps `FinEq`: on equal
operands the results are equal, and an operand that is not finite on both sides makes both
results not finite. -/
theorem FinEq.op {f : Model fmt → Model fmt → Model fmt}
    (hf : ∀ x y, (f x y).isFinite = true → x.isFinite = true ∧ y.isFinite = true)
    {x x' y y' : Model fmt} (hx : FinEq x x') (hy : FinEq y y') : FinEq (f x y) (f x' y') := by
  have nf : ∀ {a b : Model fmt}, (a.isFinite = false ∨ b.isFinite = false) →
      (f a b).isFinite = false := by
    intro a b h
    cases hab : (f a b).isFinite with
    | false => rfl
    | true =>
      obtain ⟨ha, hb⟩ := hf a b hab
      rcases h with h | h
      · rw [ha] at h
        cases h
      · rw [hb] at h
        cases h
  rcases hx with rfl | ⟨h1, h2⟩
  · rcases hy with rfl | ⟨h3, h4⟩
    · exact .inl rfl
    · exact .inr ⟨nf (.inr h3), nf (.inr h4)⟩
  · exact .inr ⟨nf (.inl h1), nf (.inl h2)⟩

/-- The format of every float type of the semantics is an IEEE format. -/
theorem isIEEE_fmt (t : FloatTy) : t.fmt.isIEEE = true := by
  cases t <;> rfl

/-- FloatLib's operations of `fadd`, `fsub` and `fmul` have finite operands where their result is
finite, on every float type (`Model.isFinite_of_isFinite_add`, `_sub`, `_mul`). -/
theorem fbin_finite {t : FloatTy} {op : FBinOp} (hop : op = .fadd ∨ op = .fsub ∨ op = .fmul)
    {f : Model t.fmt → Model t.fmt → Model t.fmt} (hf : fbin op = some f) (x y : Model t.fmt)
    (h : (f x y).isFinite = true) : x.isFinite = true ∧ y.isFinite = true := by
  rcases hop with rfl | rfl | rfl <;> simp only [fbin, Option.some.injEq] at hf <;> subst hf
  · exact Model.isFinite_of_isFinite_add (isIEEE_fmt t) h
  · exact Model.isFinite_of_isFinite_sub (isIEEE_fmt t) h
  · exact Model.isFinite_of_isFinite_mul (isIEEE_fmt t) h

/-- With no recorded factor, a contracted `fadd` / `fsub` is the separately rounded one, for every
oracle number. -/
theorem contract_none (sub : Bool) (x y : Model fmt) (n : Nat) :
    contract sub x y none none n = if sub then Model.sub x y else Model.add x y := by
  rcases contract_cases sub x y none none n with h | ⟨_, _, h, -⟩ | ⟨_, _, h, -⟩
  · exact h
  · cases h
  · cases h

/-- On two floats of type `t`, with no recorded factor and flags without `nnan`, `ninf`, `nsz`,
`reassoc`, `arcp` and `afn`, `floatBin` of an operator with IEEE operation `f` (every operator but
`frem`) is `f` through `deliver`, for every oracle number. -/
theorem floatBin_ofFloat {t : FloatTy} {op : FBinOp} {fm : FastMath}
    {f : Model t.fmt → Model t.fmt → Model t.fmt} (hf : fbin op = some f)
    (hc : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = false) (hn : fm.nnan = false)
    (hi : fm.ninf = false) (a b : Model t.fmt) (n : Nat) :
    floatBin t op fm (.ofFloat t a) (.ofFloat t b) none none n =
      .ok (.ofFloat t (deliver (f a b) (n / 3))) := by
  have e1 : (FBinOp.fadd == FBinOp.fsub) = false := rfl
  cases op <;> simp only [fbin, Option.some.injEq, reduceCtorEq] at hf <;> subst hf <;>
    simp [floatBin, FastMath.check, hc, withFlags, FastMath.poisons, hn, hi, contract_none, e1,
      Val.ofFloat, Val.float?, fbin, Model.ofBits_toBits, bind, Except.bind, pure, Except.pure]

/-- A relation on floats that relates each float to itself relates two scalars either as equal
scalars that are not floats of type `t`, or as two related floats. -/
theorem Val.Lift.cases {t : FloatTy} {R : Model t.fmt → Model t.fmt → Prop} (hR : ∀ a, R a a)
    {v v' : Val} (h : Val.Lift t R v v') :
    (v = v' ∧ v.float? t = none) ∨ ∃ a a', v = .ofFloat t a ∧ v' = .ofFloat t a' ∧ R a a' := by
  rcases h with rfl | h
  · cases hv : v.float? t with
    | none => exact .inl ⟨rfl, rfl⟩
    | some a => exact .inr ⟨a, a, Val.float?_eq_some.1 hv, Val.float?_eq_some.1 hv, hR a⟩
  · exact .inr h

/-- If the first operand is not a float of type `t`, `floatBin` with no recorded factor gives one
result on second operands related by `Val.Lift t R`, for every relation and every two oracle
numbers: a fault, or poison. -/
theorem floatBin_left {t : FloatTy} {op : FBinOp} {fm : FastMath}
    {R : Model t.fmt → Model t.fmt → Prop} {x y y' : Val} (hx : x.float? t = none)
    (hy : Val.Lift t R y y') (n n' : Nat) :
    floatBin t op fm x y none none n = floatBin t op fm x y' none none n' := by
  by_cases hc : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = true
  · simp only [floatBin, FastMath.check, hc, ↓reduceIte]
    rfl
  rcases hy with rfl | ⟨b, b', rfl, rfl, -⟩
  · rcases x with _ | _ | _ | _ | _ | _ <;> rcases y with _ | _ | _ | _ | _ | _ <;>
      simp_all [floatBin, FastMath.check, Val.float?]
  · rcases x with _ | _ | _ | _ | _ | _ <;>
      simp_all [floatBin, FastMath.check, Val.float?, Val.ofFloat]

/-- If the second operand is not a float of type `t`, `floatBin` with no recorded factor gives one
result on first operands related by `Val.Lift t R`, for every relation and every two oracle
numbers: a fault, or poison. -/
theorem floatBin_right {t : FloatTy} {op : FBinOp} {fm : FastMath}
    {R : Model t.fmt → Model t.fmt → Prop} {x x' y : Val} (hx : Val.Lift t R x x')
    (hy : y.float? t = none) (n n' : Nat) :
    floatBin t op fm x y none none n = floatBin t op fm x' y none none n' := by
  by_cases hc : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = true
  · simp only [floatBin, FastMath.check, hc, ↓reduceIte]
    rfl
  rcases hx with rfl | ⟨a, a', rfl, rfl, -⟩
  · rcases x with _ | _ | _ | _ | _ | _ <;> rcases y with _ | _ | _ | _ | _ | _ <;>
      simp_all [floatBin, FastMath.check, Val.float?]
  · rcases y with _ | _ | _ | _ | _ | _ <;>
      simp_all [floatBin, FastMath.check, Val.float?, Val.ofFloat]

/-- **The scalar rows' rule**: for every float type `t`, relation `R` on its floats that relates
each float to itself, operator with an IEEE operation `f` (`fbin op = some f`) and flags without
`nnan` and `ninf`, if `f` followed by `deliver` takes operands related by `R` to results related
by `R` for every two oracle numbers, then `floatOp` with no recorded factor respects
`Val.Lift t R` under any two oracle numbers. -/
theorem floatOp_lift {t : FloatTy} {R : Model t.fmt → Model t.fmt → Prop} (hR : ∀ a, R a a)
    {op : FBinOp} {f : Model t.fmt → Model t.fmt → Model t.fmt} (hf : fbin op = some f)
    (hd : ∀ {x x' y y'}, R x x' → R y y' → ∀ n n', R (deliver (f x y) n) (deliver (f x' y') n'))
    {fm : FastMath} (hn : fm.nnan = false) (hi : fm.ninf = false) :
    Respects (Val.Lift t R) (Val.Lift t R) (fun _ _ => True) (floatOp t op fm) := by
  have hV : ∀ v, Val.Lift t R v v := fun _ => .inl rfl
  intro xs ys n n' hxy _
  rcases hxy with _ | ⟨hx, _ | ⟨hy, _ | ⟨_, _⟩⟩⟩
  · exact .error _
  · exact .error _
  · show Except.Rel _ (floatBin t op fm _ _ none none n) (floatBin t op fm _ _ none none n')
    by_cases hc : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = true
    · simp only [floatBin, FastMath.check, hc, ↓reduceIte]
      exact .error _
    rw [Bool.not_eq_true] at hc
    rcases Val.Lift.cases hR hx with ⟨rfl, hxn⟩ | ⟨a, a', rfl, rfl, ha⟩
    · rw [floatBin_left hxn hy n n']
      exact Except.Rel.refl hV _
    rcases Val.Lift.cases hR hy with ⟨rfl, hyn⟩ | ⟨b, b', rfl, rfl, hb⟩
    · rw [floatBin_right (.inr ⟨a, a', rfl, rfl, ha⟩) hyn n n']
      exact Except.Rel.refl hV _
    rw [floatBin_ofFloat hf hc hn hi, floatBin_ofFloat hf hc hn hi]
    exact .ok (.inr ⟨_, _, rfl, rfl, hd ha hb _ _⟩)
  · exact .error _

/-- **`fadd`, `fsub` and `fmul` respect `FinEq`**: for every float type `t`, `fadd`, `fsub` and
`fmul` with no recorded factor and flags without `nnan` and `ninf` respect `Val.Lift t FinEq`
under any two oracle numbers: on related operands both fault alike, or the results are equal
scalars or two floats that are equal or both not finite (`floatOp_lift` with `FinEq.op` and
`FinEq.deliver`). -/
theorem floatOp_finEq (t : FloatTy) {op : FBinOp} (hop : op = .fadd ∨ op = .fsub ∨ op = .fmul)
    {fm : FastMath} (hn : fm.nnan = false) (hi : fm.ninf = false) :
    Respects (Val.Lift t FinEq) (Val.Lift t FinEq) (fun _ _ => True) (floatOp t op fm) := by
  obtain ⟨f, hf⟩ : ∃ f, fbin (fmt := t.fmt) op = some f := by
    rcases hop with rfl | rfl | rfl <;> exact ⟨_, rfl⟩
  exact floatOp_lift (fun _ => .inl rfl) hf
    (fun hx hy n n' => (FinEq.op (fbin_finite hop hf) hx hy).deliver n n') hn hi

/-- **T5's NaN row**: for every format and every operator with an IEEE 754 operation `f` (`fadd`,
`fsub`, `fmul`, `fdiv`; `frem` has none), if an operand is a NaN the result is a NaN. A NaN has no
dyadic value (`Model.toDyadic?`), so FloatLib's specification of each operation takes the branch of
`Model.chooseNaN2`, which returns a quieted NaN operand; `fsub` is `fadd` of the negation, which
keeps a NaN a NaN. -/
theorem fbin_isNaN {op : FBinOp} {f : Model fmt → Model fmt → Model fmt} (hf : fbin op = some f)
    {x y : Model fmt} (h : x.isNaN = true ∨ y.isNaN = true) : (f x y).isNaN = true := by
  have hc : ∀ {x y : Model fmt}, (x.isNaN = true ∨ y.isNaN = true) →
      ∃ r, Model.chooseNaN2 x y = some r ∧ r.isNaN = true := by
    intro x y h
    cases hn : Model.chooseNaN2 x y with
    | none =>
      have := (Model.chooseNaN2_eq_none_iff x y).1 hn
      rcases h with h | h <;> simp_all
    | some r => exact ⟨r, rfl, Model.isNaN_of_chooseNaN2_eq_some hn⟩
  have hd : ∀ {x y : Model fmt}, (x.isNaN = true ∨ y.isNaN = true) → ∀ {dx dy},
      Model.toDyadic? x = some dx → Model.toDyadic? y = some dy → False := by
    rintro x y (h | h) dx dy hx hy
    · rw [Model.toDyadic?_eq_none_of_isNaN h] at hx
      cases hx
    · rw [Model.toDyadic?_eq_none_of_isNaN h] at hy
      cases hy
  have hadd : ∀ {x y : Model fmt}, (x.isNaN = true ∨ y.isNaN = true) →
      (Model.Spec.add x y).isNaN = true := by
    intro x y h
    unfold Model.Spec.add
    split
    · exact (hd h ‹_› ‹_›).elim
    · obtain ⟨r, e, hr⟩ := hc h
      rw [e]
      exact hr
  cases op <;> simp only [fbin, Option.some.injEq, reduceCtorEq] at hf <;> subst hf <;>
    beta_reduce
  · rw [Model.Proof.add_eq_spec]
    exact hadd h
  · rw [Model.Proof.sub_eq_spec]
    unfold Model.Spec.sub
    exact hadd (by rwa [Model.isNaN_neg])
  · rw [Model.Proof.mul_eq_spec]
    unfold Model.Spec.mul
    split
    · exact (hd h ‹_› ‹_›).elim
    · obtain ⟨r, e, hr⟩ := hc h
      rw [e]
      exact hr
  · rw [Model.Proof.div_eq_spec]
    unfold Model.Spec.div
    split
    · exact (hd h ‹_› ‹_›).elim
    · unfold Model.Spec.divSpecial
      obtain ⟨r, e, hr⟩ := hc h
      rw [e]
      exact hr

/-- Every operator but `frem` has an IEEE operation, in every format. -/
theorem fbin_some {op : FBinOp} (hop : op ≠ .frem) : ∃ f, fbin (fmt := fmt) op = some f := by
  cases op <;> first | exact absurd rfl hop | exact ⟨_, rfl⟩

/-- Every operator with an IEEE operation `f` keeps `NaNEq`: on equal operands the results are
equal, and an operand that is a NaN on both sides makes both results NaNs (`fbin_isNaN`). -/
theorem NaNEq.op {op : FBinOp} {f : Model fmt → Model fmt → Model fmt} (hf : fbin op = some f)
    {x x' y y' : Model fmt} (hx : NaNEq x x') (hy : NaNEq y y') : NaNEq (f x y) (f x' y') := by
  rcases hx with rfl | ⟨h1, h2⟩
  · rcases hy with rfl | ⟨h3, h4⟩
    · exact .inl rfl
    · exact .inr ⟨fbin_isNaN hf (.inr h3), fbin_isNaN hf (.inr h4)⟩
  · exact .inr ⟨fbin_isNaN hf (.inl h1), fbin_isNaN hf (.inl h2)⟩

/-- **NaN equivalence under free oracles** (T5's NaN row as a `Respects` statement): for every
float type `t`, `fadd`, `fsub`, `fmul` and `fdiv` with no recorded factor and flags without `nnan`
and `ninf` respect `Val.Lift t NaNEq` under any two oracle numbers: on related operands both fault
alike, or the results are equal scalars or two floats that are equal or both NaNs (`floatOp_lift`
with `NaNEq.op` and `NaNEq.deliver`). -/
theorem floatOp_nanEq (t : FloatTy) {op : FBinOp} (hop : op ≠ .frem) {fm : FastMath}
    (hn : fm.nnan = false) (hi : fm.ninf = false) :
    Respects (Val.Lift t NaNEq) (Val.Lift t NaNEq) (fun _ _ => True) (floatOp t op fm) := by
  obtain ⟨f, hf⟩ := fbin_some (fmt := t.fmt) hop
  exact floatOp_lift (fun _ => .inl rfl) hf (fun hx hy n n' => (NaNEq.op hf hx hy).deliver n n')
    hn hi

/-- **T5's NaN row through `floatBin`**: for every float type, operator other than `frem`, flags
without `nnan`, `ninf`, `nsz`, `reassoc`, `arcp` and `afn` (`contract` is allowed: with no recorded
factor it is the separately rounded operation), and oracle number `k`, `floatOp` on two floats of
which one is a NaN gives a NaN (`fbin_isNaN`; `deliver` keeps a NaN a NaN). -/
theorem floatOp_isNaN (t : FloatTy) {op : FBinOp} (hop : op ≠ .frem) {fm : FastMath}
    (hc : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = false) (hn : fm.nnan = false)
    (hi : fm.ninf = false) {a b : Model t.fmt} (h : a.isNaN = true ∨ b.isNaN = true) (k : Nat) :
    ∃ r, floatOp t op fm [.ofFloat t a, .ofFloat t b] k = .ok (.ofFloat t r) ∧ r.isNaN = true := by
  obtain ⟨f, hf⟩ := fbin_some (fmt := t.fmt) hop
  exact ⟨_, floatBin_ofFloat hf hc hn hi a b k, isNaN_deliver (fbin_isNaN hf h) _⟩

/-- **The `rsqrt.approx` relation**: for every positive binary32 `x` that is finite, not
zero and not subnormal, the value of `rsqrt.approx.ftz.f32` of `x`, for every oracle number, is
finite and within relative error `rsqrtErr` of `1 / √x`. -/
theorem rsqrt_close {x : Model .binary32} (hf : x.isFinite = true) (hz : x.isZero = false)
    (hs : x.isSubnormal = false) (hp : x.signBit = false) (n : Nat) :
    RsqrtClose x.toReal (rsqrt x n) := by
  have hok := rsqrtOk_of_rsqrt x n
  generalize rsqrt x n = w at hok ⊢
  have hn : x.isNaN = false := Model.isNaN_eq_false_of_isFinite_eq_true x hf
  have hi : x.isInfinite = false := Model.isInfinite_eq_false_of_isFinite_eq_true x hf
  obtain ⟨a, ha⟩ : ∃ a, x.toRat? = some a :=
    Option.isSome_iff_exists.1 (by rw [Model.Algebraic.toRat?_isSome_eq_isFinite]; exact hf)
  unfold rsqrtOk at hok
  simp only [hn, hz, hs, hp, hi, Bool.or_false, Bool.false_eq_true, ↓reduceIte, ha] at hok
  cases hb : w.toRat? with
  | none => simp [hb] at hok
  | some b =>
    simp only [hb, Bool.and_eq_true] at hok
    have har : x.toReal = a := Model.Algebraic.toReal_of_toRat?_eq_some ha
    have hbr : w.toReal = b := Model.Algebraic.toReal_of_toRat?_eq_some hb
    have hwf : w.isFinite = true := by
      rw [← Model.Algebraic.toRat?_isSome_eq_isFinite, hb]
      rfl
    have h0 : (0 : ℝ) < a := by
      rw [← har]
      rcases (Model.toReal_nonneg_of_signBit_eq_false hp).lt_or_eq with h | h
      · exact h
      · have := (Model.isZero_eq_true_iff_toReal_eq_zero x hf).2 h.symm
        rw [hz] at this
        cases this
    unfold RsqrtClose
    rw [har, hbr]
    exact ⟨hwf, (rsqrtNear_iff (by exact_mod_cast h0)).1 hok.2⟩

/-- **`maxnum` / `minnum` without NaN choice**: for every format, with no signaling NaN
operand and not both operands NaNs, `maxnum` (`max`) or `minnum` is FloatLib's `maximumNumber` or
`minimumNumber`, for every oracle number; so two runs give equal words. -/
theorem maxnum_of_not_nan {max : Bool} {x y : Model fmt}
    (hs : (x.isSignaling || y.isSignaling) = false) (hb : x.isNaN = false ∨ y.isNaN = false)
    (n : Nat) :
    maxnum max x y n = if max then Model.maximumNumber x y else Model.minimumNumber x y := by
  have hr : (if max then Model.maximumNumber x y else Model.minimumNumber x y).isNaN = false := by
    cases max
    · exact Model.isNaN_minimumNumber_eq_false_of_not_both x y hb
    · exact Model.isNaN_maximumNumber_eq_false_of_not_both x y hb
  simp only [maxnum, hs, Bool.false_and, Bool.false_eq_true, ↓reduceIte]
  exact deliver_of_isNaN_eq_false hr _

/-- **`maxnum` / `minnum` under coupled oracle numbers**: for every format and operands, two
oracle numbers of one parity give `NaNEq` results: both runs take the same arm, and `deliver` keeps
`NaNEq`. -/
theorem maxnum_nanEq (max : Bool) (x y : Model fmt) {n n' : Nat} (h : n % 2 = n' % 2) :
    NaNEq (maxnum max x y n) (maxnum max x y n') := by
  unfold maxnum
  rw [← h]
  split_ifs <;> exact NaNEq.deliver (.inl rfl) _ _

/-- **`maxnum` and `minnum` at the intrinsic, on scalars**: for every `max` flag, type `t` whose
element type is the float type `ft`, words `a` and `b` of `ft`, context, scope `s` and flags `fm`,
the call of `llvm.maxnum` (`max`) or `llvm.minnum` on the scalars of `a` and `b` returns the scalar
of `maxnum max a b` at `s`'s oracle number 0, or poison if `withFlags fm` makes it poison, and
leaves `s`'s memory. -/
theorem intrinsic_fminmax_ofFloat {max : Bool} {t : Ty} {ft : FloatTy} (ht : t.elt = .fp ft)
    (a b : Model ft.fmt) (c : Ctx) (s : Scope) (fm : FastMath) :
    intrinsic c s fm (.fminmax max t) [.ofFloat ft a, .ofFloat ft b] =
      .ok (some (some ((withFlags fm [a, b] (maxnum max a b (s.ch 0))).elim .poison
        (.ofFloat ft)), s.mem)) := by
  have hl : ∀ f : Nat → Val → Val → Except Fault Val,
      lanes2 f (.ofFloat ft a) (.ofFloat ft b) = f 0 (.ofFloat ft a) (.ofFloat ft b) :=
    fun _ => rfl
  have hg : ∀ g : Model ft.fmt → Model ft.fmt → Val,
      floats2 ft g (.ofFloat ft a) (.ofFloat ft b) = .ok (g a b) := by
    intro g
    have ea := Val.float?_ofFloat ft a
    have eb := Val.float?_ofFloat ft b
    unfold Val.ofFloat at ea eb ⊢
    simp only [floats2, strict2, ea, eb, pure, Except.pure]
  simp only [intrinsic, ht, hl, hg]
  cases withFlags fm [a, b] (maxnum max a b (s.ch 0)) <;> rfl

/-- **Row `maxnum` / `minnum` at the intrinsic, free** (`maxnum_of_not_nan` through
`intrinsic_fminmax_ofFloat`): with no signaling NaN operand and not both operands NaNs, the call
of `llvm.maxnum` or `llvm.minnum` on the scalars of `a` and `b` returns, for every context, scope
`s` and flags `fm`, the scalar of `maximumNumber a b` or `minimumNumber a b`, or poison if
`withFlags fm` makes it poison, and leaves `s`'s memory: no oracle number appears. -/
theorem fminmax_of_not_nan {max : Bool} {t : Ty} {ft : FloatTy} (ht : t.elt = .fp ft)
    {a b : Model ft.fmt} (hs : (a.isSignaling || b.isSignaling) = false)
    (hb : a.isNaN = false ∨ b.isNaN = false) (c : Ctx) (s : Scope) (fm : FastMath) :
    intrinsic c s fm (.fminmax max t) [.ofFloat ft a, .ofFloat ft b] =
      .ok (some (some ((withFlags fm [a, b]
        (if max then Model.maximumNumber a b else Model.minimumNumber a b)).elim .poison
        (.ofFloat ft)), s.mem)) := by
  rw [intrinsic_fminmax_ofFloat ht, maxnum_of_not_nan hs hb]

/-- **Row `maxnum` / `minnum` at the intrinsic, coupled** (`maxnum_nanEq` through
`intrinsic_fminmax_ofFloat`): with flags without `nnan` and `ninf`, for all words `a` and `b`, two
contexts and two scopes whose oracle numbers 0 have one parity, the calls of `llvm.maxnum` or
`llvm.minnum` on the scalars of `a` and `b` return scalars related by `Val.Lift ft NaNEq`, each
leaving its scope's memory. -/
theorem fminmax_nanEq {fm : FastMath} (hn : fm.nnan = false) (hi : fm.ninf = false) (max : Bool)
    {t : Ty} {ft : FloatTy} (ht : t.elt = .fp ft) (a b : Model ft.fmt) (c c' : Ctx)
    {s s' : Scope} (h : s.ch 0 % 2 = s'.ch 0 % 2) :
    Except.Rel (Option.Rel fun r r' => Option.Rel (Val.Lift ft NaNEq) r.1 r'.1 ∧ r.2 = s.mem ∧
        r'.2 = s'.mem)
      (intrinsic c s fm (.fminmax max t) [.ofFloat ft a, .ofFloat ft b])
      (intrinsic c' s' fm (.fminmax max t) [.ofFloat ft a, .ofFloat ft b]) := by
  rw [intrinsic_fminmax_ofFloat ht, intrinsic_fminmax_ofFloat ht, withFlags_some hn hi,
    withFlags_some hn hi]
  exact .ok (.some ⟨.some (.inr ⟨_, _, rfl, rfl, maxnum_nanEq max a b h⟩), rfl, rfl⟩)

/-- **`maxnum` and `minnum` at the intrinsic, on vectors**: for every `max` flag, type `t` whose
element type is the float type `ft`, lists of words `as` and `bs` of one length, context, scope `s`
and flags `fm`, the call of `llvm.maxnum` (`max`) or `llvm.minnum` on the vectors of the scalars
of `as` and `bs` returns the vector whose lane `j` is the scalar of `maxnum max a b` of the lane's
words at `s`'s oracle number `j`, or poison if `withFlags fm` makes it poison, and leaves `s`'s
memory. -/
theorem intrinsic_fminmax_vec {max : Bool} {t : Ty} {ft : FloatTy} (ht : t.elt = .fp ft)
    {as bs : List (Model ft.fmt)} (hl : as.length = bs.length) (c : Ctx) (s : Scope)
    (fm : FastMath) :
    intrinsic c s fm (.fminmax max t)
        [.vec (as.map (.ofFloat ft)), .vec (bs.map (.ofFloat ft))] =
      .ok (some (some (.vec ((as.zip bs).zipIdx.map fun ((a, b), j) =>
        (withFlags fm [a, b] (maxnum max a b (s.ch j))).elim .poison (.ofFloat ft))), s.mem)) := by
  have hg : ∀ (g : Model ft.fmt → Model ft.fmt → Val) (a b : Model ft.fmt),
      floats2 ft g (.ofFloat ft a) (.ofFloat ft b) = .ok (g a b) := by
    intro g a b
    have ea := Val.float?_ofFloat ft a
    have eb := Val.float?_ofFloat ft b
    unfold Val.ofFloat at ea eb ⊢
    simp only [floats2, strict2, ea, eb, pure, Except.pure]
  simp only [intrinsic, ht, lanes2, List.length_map, hl, ↓reduceIte]
  rw [List.zip_map, List.zipIdx_map, List.mapM_map,
    mapM_congr (g := fun x => pure ((withFlags fm [x.1.1, x.1.2]
      (maxnum max x.1.1 x.1.2 (s.ch x.2))).elim .poison (.ofFloat ft))) (fun x _ => ?_),
    List.mapM_pure]
  · rfl
  · obtain ⟨⟨a, b⟩, j⟩ := x
    simp only [Function.comp, Prod.map, id]
    rw [hg]
    cases withFlags fm [a, b] (maxnum max a b (s.ch j)) <;> rfl

/-- **Row `maxnum` / `minnum` at the intrinsic on vectors, free** (`maxnum_of_not_nan` through
`intrinsic_fminmax_vec`): if no lane has a signaling NaN operand or two NaN operands, the call of
`llvm.maxnum` or `llvm.minnum` on the vectors of `as` and `bs` returns, for every context, scope
`s` and flags `fm`, the vector of the scalars of `maximumNumber a b` or `minimumNumber a b` of the
lanes' words, or poison where `withFlags fm` makes it poison, and leaves `s`'s memory: no oracle
number appears. -/
theorem fminmax_vec_of_not_nan {max : Bool} {t : Ty} {ft : FloatTy} (ht : t.elt = .fp ft)
    {as bs : List (Model ft.fmt)} (hl : as.length = bs.length)
    (hn : ∀ a b, (a, b) ∈ as.zip bs →
      (a.isSignaling || b.isSignaling) = false ∧ (a.isNaN = false ∨ b.isNaN = false))
    (c : Ctx) (s : Scope) (fm : FastMath) :
    intrinsic c s fm (.fminmax max t)
        [.vec (as.map (.ofFloat ft)), .vec (bs.map (.ofFloat ft))] =
      .ok (some (some (.vec ((as.zip bs).map fun (a, b) => (withFlags fm [a, b]
        (if max then Model.maximumNumber a b else Model.minimumNumber a b)).elim .poison
          (.ofFloat ft))), s.mem)) := by
  rw [intrinsic_fminmax_vec ht hl]
  congr 4
  conv => rhs; rw [← List.zipIdx_map_fst 0 (as.zip bs), List.map_map]
  refine congrArg Val.vec (List.map_congr_left fun x hm => ?_)
  obtain ⟨⟨a, b⟩, j⟩ := x
  obtain ⟨hs, hb⟩ := hn a b (List.fst_mem_of_mem_zipIdx hm)
  simp only [Function.comp, maxnum_of_not_nan hs hb]

/-- **Row `maxnum` / `minnum` at the intrinsic on vectors, coupled lane by lane**
(`maxnum_nanEq` through `intrinsic_fminmax_vec`): with flags without `nnan` and `ninf`, for all
lists of words `as` and `bs` of one length, two contexts and two scopes whose oracle numbers `j`
have one parity at every lane `j`, the calls of `llvm.maxnum` or `llvm.minnum` on the vectors of
`as` and `bs` return vectors whose lanes are related by `Val.Lift ft NaNEq`, each call leaving its
scope's memory. -/
theorem fminmax_vec_nanEq {fm : FastMath} (hn : fm.nnan = false) (hi : fm.ninf = false)
    (max : Bool) {t : Ty} {ft : FloatTy} (ht : t.elt = .fp ft) {as bs : List (Model ft.fmt)}
    (hl : as.length = bs.length) (c c' : Ctx) {s s' : Scope}
    (h : ∀ j < as.length, s.ch j % 2 = s'.ch j % 2) :
    ∃ xs ys, intrinsic c s fm (.fminmax max t)
          [.vec (as.map (.ofFloat ft)), .vec (bs.map (.ofFloat ft))] =
        .ok (some (some (.vec xs), s.mem)) ∧
      intrinsic c' s' fm (.fminmax max t)
          [.vec (as.map (.ofFloat ft)), .vec (bs.map (.ofFloat ft))] =
        .ok (some (some (.vec ys), s'.mem)) ∧
      List.Forall₂ (Val.Lift ft NaNEq) xs ys := by
  refine ⟨_, _, intrinsic_fminmax_vec ht hl c s fm, intrinsic_fminmax_vec ht hl c' s' fm, ?_⟩
  rw [List.forall₂_map_left_iff, List.forall₂_map_right_iff, List.forall₂_same]
  rintro ⟨⟨a, b⟩, j⟩ hm
  have hj : j < as.length := by
    have := (List.mem_zipIdx hm).2.1
    simp only [List.length_zip, hl, Nat.min_self, Nat.zero_add] at this
    omega
  simp only [withFlags_some hn hi, Option.elim]
  exact .inr ⟨_, _, rfl, rfl, maxnum_nanEq max a b (h j hj)⟩

/-- The estimate of a contracted `fadd` (`fsub` if `sub`) of `a` and `b` with `fmul contract`
factors `pa`, `pb` (the error relation's row of docs/proofs/payload.md): the value
`exact a pa ± exact b pb`, `contract_error`'s bound, valid when `a` and `b` are finite and each
of the three choices' exact results (unfused, fused with `a`'s factors, fused with `b`'s) is at
most the largest finite magnitude, so that none overflows. -/
noncomputable def Est.contract (sub : Bool) (a b : Model fmt)
    (pa pb : Option (Model fmt × Model fmt)) : Est :=
  let s : ℝ := if sub then -1 else 1
  let M := (Model.posMaxFinite fmt).toReal
  { value := exact a pa + s * exact b pb
    bound := max (factorErr pa + factorErr pb + Model.halfUlpAt fmt (a.toReal + s * b.toReal))
      (max (factorErr pb + Model.halfUlpAt fmt (exact a pa + s * b.toReal))
        (factorErr pa + Model.halfUlpAt fmt (a.toReal + s * exact b pb)))
    valid := decide (a.isFinite = true ∧ b.isFinite = true ∧ |a.toReal + s * b.toReal| ≤ M ∧
      |exact a pa + s * b.toReal| ≤ M ∧ |a.toReal + s * exact b pb| ≤ M) }

/-- The factors of a finite rounded product are finite. -/
theorem IsProd.factors_finite (hfmt : fmt.isIEEE = true) {x a b : Model fmt}
    (h : IsProd x (some (a, b))) (hx : x.isFinite = true) :
    a.isFinite = true ∧ b.isFinite = true :=
  Model.isFinite_of_isFinite_mul hfmt (h a b rfl hx).1

/-- **The error relation's row, on words.** For every IEEE format, `sub`, operands `a`, `b` that
are rounded products of their factors `pa`, `pb` (`IsProd`) and every oracle number `n`, the
contracted result `contract sub a b pa pb n` meets `Est.contract sub a b pa pb`: when the
estimate is valid, the result is finite and within `contract_error`'s bound of
`exact a pa ± exact b pb`. -/
theorem contract_est (hfmt : fmt.isIEEE = true) (sub : Bool) {a b : Model fmt}
    {pa pb : Option (Model fmt × Model fmt)} (ha : IsProd a pa) (hb : IsProd b pb) (n : Nat) :
    (Est.contract sub a b pa pb).Holds (contract sub a b pa pb n) := by
  intro hv
  simp only [Est.contract, decide_eq_true_eq] at hv
  obtain ⟨fa, fb, h0, h1, h2⟩ := hv
  have hfin : (contract sub a b pa pb n).isFinite = true := by
    rcases contract_cases sub a b pa pb n with hr | ⟨u, v, rfl, hr⟩ | ⟨c, d, rfl, hr⟩ <;>
      rw [hr]
    · cases sub
      · exact Model.isFinite_add_of_abs_toReal_add_le_posMaxFinite a b hfmt fa fb
          (by simpa using h0)
      · exact Model.isFinite_sub_of_abs_toReal_sub_le_posMaxFinite a b hfmt fa fb
          (by simpa [sub_eq_add_neg] using h0)
    · obtain ⟨fu, fv⟩ := ha.factors_finite hfmt fa
      apply Model.isFinite_fma_of_abs_toReal_fma_le_posMaxFinite u v _ hfmt fu fv
        (by cases sub <;> simpa using fb)
      cases sub <;> simpa [exact, Model.toReal_neg b fb, sub_eq_add_neg] using h1
    · obtain ⟨fc, fd⟩ := hb.factors_finite hfmt fb
      apply Model.isFinite_fma_of_abs_toReal_fma_le_posMaxFinite _ d a hfmt
        (by cases sub <;> simpa using fc) fd fa
      cases sub <;> simpa [exact, Model.toReal_neg c fc, add_comm, mul_assoc] using h2
  exact ⟨hfin, contract_error hfmt sub ha hb n hfin⟩

/-- A word an operation gives with flags `fm` and oracle number `k` from the IEEE 754 result `c`
meets every estimate `c` meets: a valid estimate makes `c` finite, so not a NaN, so `deliver`
keeps it. -/
theorem holds_withFlags {e : Est} {fm : FastMath} {args : List (Model fmt)} {c r : Model fmt}
    {k : Nat} (h : MojoProof.Sem.withFlags fm args (deliver c k) = some r) (he : e.Holds c) :
    e.Holds r := by
  intro hv
  obtain ⟨hc, hb⟩ := he hv
  have hn : c.isNaN = false := by
    cases hn : c.isNaN
    · rfl
    · simp [Model.isFinite_eq_false_of_isNaN hn] at hc
  rw [deliver_of_isNaN_eq_false hn] at h
  unfold MojoProof.Sem.withFlags at h
  split_ifs at h
  cases h
  exact ⟨hc, hb⟩

/-- **The error relation at `floatBin`.** For every float type, `fadd` or `fsub` with `contract`
and any other flags, operands `a`, `b` that are rounded products of their recorded factors `pa`,
`pb` (`IsProd`), and every oracle number: a float `r` that `floatBin` gives meets
`Est.contract`, so when the estimate is valid `r` is finite and within
`contract_error`'s bound of `exact a pa ± exact b pb`. Free: no condition on the oracle. -/
theorem floatBin_contract_est {t : FloatTy} {op : FBinOp} (hop : op = .fadd ∨ op = .fsub)
    {fm : FastMath} (hc : fm.contract = true) {a b r : Model t.fmt}
    {pa pb : Option (Model t.fmt × Model t.fmt)} (ha : IsProd a pa) (hb : IsProd b pb) {n : Nat}
    (h : floatBin t op fm (.ofFloat t a) (.ofFloat t b)
      (pa.map fun (u, v) => (.ofFloat t u, .ofFloat t v))
      (pb.map fun (u, v) => (.ofFloat t u, .ofFloat t v)) n = .ok (.ofFloat t r)) :
    (Est.contract (op == .fsub) a b pa pb).Holds r := by
  have he := contract_est (isIEEE_fmt t) (op == .fsub) ha hb n
  by_cases hf : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = true
  · simp [floatBin, FastMath.check, hf, bind, Except.bind, throw, throwThe,
      MonadExceptOf.throw] at h
  rcases hop with rfl | rfl <;> rcases pa with _ | ⟨u, v⟩ <;> rcases pb with _ | ⟨u', v'⟩ <;>
  · simp only [Bool.not_eq_true] at hf
    simp [floatBin, FastMath.check, hf, hc, Val.ofFloat, Val.float?, fbin,
      Model.ofBits_toBits] at h
    split at h
    · simp [pure, Except.pure] at h
      have := congrArg Model.ofBits h
      simp only [Model.ofBits_toBits] at this
      subst this
      exact holds_withFlags (by assumption) he
    · simp [pure, Except.pure] at h

end MojoProof.Sem
