import MojoProof.Sem.FloatRel

/-!
# Instances and twins of the relations and rows of MojoProof/Sem/FloatRel.lean

On binary32, by evaluation, with three float counterexamples
(`oracleTests` in MojoProofTest/Eval.lean evaluates the same values):

* `FinEq`: `+∞` and a NaN are related; the two contracted results `+0` and `-2 ^ -46` of
  `fadd contract` of the product `(1 + 2 ^ -23) (1 - 2 ^ -23)` and `-1`, under the oracle numbers 0
  and 1, are not, so a recorded factor breaks row 1 under free oracles (`finEq_inst`).
* `NaNEq`: two different NaNs are related; `maxnum` of a signaling NaN and 1 under the oracle
  numbers 1 and 0, a NaN and 1, are not (`nanEq_inst`).
* `Est.Holds`: the estimate `-2 ^ -46` with bound `2 ^ -46` holds of both contracted results; with
  bound 0 it holds of the fused one and not of the unfused one; an estimate that is not valid holds
  of a NaN, and a valid one does not (`est_inst`).
* `Est.contract`, the instance of `floatBin_contract_est` (the error relation's row):
  `fadd contract` of `ct`'s product, with its factors, and `-1` gives `ct n` for the oracle
  numbers 0, 1 and 2; its
  estimate is valid with value `-2 ^ -46`, and each `ct n` is finite and within its bound
  (`contract_est_inst`). The twin of the validity flag: `fadd contract` of the largest finite
  number with itself gives `+∞`; its estimate is not valid, and with the flag set it would not hold
  (`contract_est_twin`).
* `RsqrtClose`, the instance of `rsqrt_close`: `rsqrt.approx` of 1 is the word of 1 under one oracle
  number and the word of `1 + 2 ^ -23` under another, different words that are both close at 1;
  the word of `1 + 2 ^ -22` is not (`rsqrt_inst`).
* `rsqrtOk_of_rsqrt` and the fallback `Model.rSqrt` on PTX's special operands: under oracle
  numbers whose words miss the contract, `rsqrt.approx` of `+∞` is `+0` (the oracle's `-0` misses),
  of the negative subnormal `-2 ^ -149` (flushed to `-0`) is `-∞`, and of `-1` a NaN; at 1 the
  oracle number 0's word `+0` misses the contract, `rsqrt.approx` gives the fallback 1, which meets
  it (`rsqrt_special`).
* `maxnum_of_not_nan`: `maxnum` of 1 and 2 is 2, and of a quiet NaN and 1 is 1, under every oracle
  number; the twin of its premise on signaling NaNs is `nanEq_inst`'s pair; the twin of its
  premise "not both NaNs": `maxnum` of two quiet NaNs under the oracle numbers `2 * 0x7fc00000` and
  `2 * 0x7fc00001` gives two different NaNs (`maxnum_inst`).
* `maxnum_nanEq`: `mx 1` and `mx 0xff800003`, of one parity, are two different NaNs, related by
  `NaNEq`; the twin of its coupling is `nanEq_inst`'s pair (`maxnum_coupled`).
* `fminmax_of_not_nan` and `fminmax_nanEq`, the rows at the intrinsic, on binary32 scalars with no
  flags, for every context and scope (`mxI`, evaluated by `mxI_eq`): `llvm.maxnum` of 1 and 2 is 2,
  and of a signaling NaN and 1 under two scopes whose oracle numbers 0 have one parity the results
  are related by `Val.Lift .float NaNEq` (`fminmax_inst`). Twins (`fminmax_twin`): of the premise
  "not both NaNs", `llvm.maxnum` of the quiet NaNs `0x7fc00000` and `0x7fc00001` under the oracle
  numbers `2 * 0x7fc00000` and `2 * 0x7fc00001` gives the scalars of two different NaNs; of the
  coupling, under the oracle numbers 1 and 0 `llvm.maxnum` of a signaling NaN and 1 gives the
  scalars of `mx 1` and `mx 0`, which `NaNEq` does not relate.
* `fminmax_vec_of_not_nan` and `fminmax_vec_nanEq`, the rows at the intrinsic on vectors, at
  `<2 x float>` with no flags, for every context and scope (`mxV`, evaluated by `mxV_eq`):
  `llvm.maxnum` of `<1, qNaN>` and `<2, 1>` is `<2, 1>` (`fminmax_vec_inst`); of `<sNaN, 1>` and
  `<1, 2>` under two scopes whose oracle numbers 0 and 1 have one parity each, the lanes are
  related by `Val.Lift .float NaNEq` (`fminmax_vec_coupled`). Twins (`fminmax_vec_twin`): of the
  coupling lane by lane, two scopes whose oracle numbers 0 agree and whose oracle numbers 1 are 1
  and 0 give, on `<1, sNaN>` and `<2, 1>`, lanes 1 that `Val.Lift .float NaNEq` does not relate;
  of the premise "no lane has two NaN operands", two quiet NaNs at lane 0 under the oracle numbers
  `2 * 0x7fc00000` and `2 * 0x7fc00001` give two different NaNs.
* `Respects`, the instance of `floatOp_finEq`: `fadd` of `+∞` and 1 and of a NaN and 1 under the
  oracle numbers 0 and 5 give related results; the twin of its premise `nnan = false`: with `nnan`
  the first is `+∞` and the second poison, which `Val.Lift` does not relate; the twin of its
  premise on the operator: `fdiv` of 1 by `+∞` and by a NaN gives `+0` and a NaN, which are not
  related (`row1_inst`).
* `floatOp_isNaN`, T5's NaN row: `fadd` with no flags of a quiet NaN and 1, and `fadd contract` of
  1 and a signaling NaN, give NaNs, for every oracle number (`nan_row_inst`). Twins
  (`nan_row_twin`, at oracle number 0): of the premise that an operand is a NaN, `fadd` of 1 and 1
  gives 2, not a NaN; of `nnan = false`, `fadd nnan` of the quiet NaN and 1 is poison
  (`row1_inst`); of `ninf = false`, `fadd ninf` of the quiet NaN and `+∞` is poison; of the
  premise on `nsz`, `reassoc`, `arcp` and `afn`, `fadd nsz` faults; of the premise on the operator,
  `frem` faults.
* `floatOp_nanEq`, NaN equivalence under free oracles: `fadd` with no flags of two different quiet
  NaNs with 1, under the oracle numbers 0 and 5, gives results related by `Val.Lift .float NaNEq`;
  the twin of its operand relation: `fadd` of `+∞` and 1 and of a quiet NaN and 1, operands related
  by `FinEq` and not by `NaNEq`, gives `+∞` and a NaN, which `NaNEq` does not relate
  (`nanEq_row_inst`).
-/

namespace MojoProofTest.FloatRel

open MojoProof.Sem MojoProof.LLVM FloatLib.Floats.Formats.BinaryInterchange

/-- The binary32 word with bits `n`. -/
def f32 (n : Nat) : Model .binary32 := Model.ofNatBits n

/-- `fadd contract` of the product `(1 + 2 ^ -23) (1 - 2 ^ -23)`, with its factors, and `-1`, under
oracle number `n`: unfused for `n = 0`, fused for `n = 1`. -/
def ct (n : Nat) : Model .binary32 :=
  contract false (Model.mul (f32 0x3f800001) (f32 0x3f7ffffe)) (f32 0xbf800000)
    (some (f32 0x3f800001, f32 0x3f7ffffe)) none n

/-- The unfused result is `+0` and the fused one `-2 ^ -46`. -/
theorem ct_vals : (ct 0).toRat? = some 0 ∧ (ct 1).toRat? = some (-1 / 70368744177664) := by
  decide +kernel

/-- The instance of `FinEq`: `+∞` and a NaN are related. Its twin: the two contracted results
`ct 0`, `+0`, and `ct 1`, `-2 ^ -46`, are not, both being finite. -/
theorem finEq_inst : FinEq (f32 0x7f800000) (f32 0x7fc00000) ∧ ¬ FinEq (ct 0) (ct 1) := by
  refine ⟨Or.inr ⟨by decide +kernel, by decide +kernel⟩, ?_⟩
  rintro (h | ⟨h, -⟩)
  · have := congrArg Model.toRat? h
    rw [ct_vals.1, ct_vals.2] at this
    exact absurd (Option.some.inj this) (by norm_num)
  · simp [Model.Algebraic.isFinite_of_toRat?_eq_some ct_vals.1] at h

/-- `maxnum` of a signaling NaN and 1 under oracle number `n`: a NaN for odd `n`, 1 for even. -/
def mx (n : Nat) : Model .binary32 := maxnum true (f32 0x7fa00000) (f32 0x3f800000) n

/-- The instance of `NaNEq`: the NaNs `0x7fc00000` and `0x7fc00001` are related. Its twin: `mx 1`, a
NaN, and `mx 0`, the word of 1, are not. -/
theorem nanEq_inst : NaNEq (f32 0x7fc00000) (f32 0x7fc00001) ∧ ¬ NaNEq (mx 1) (mx 0) := by
  refine ⟨Or.inr ⟨by decide +kernel, by decide +kernel⟩, ?_⟩
  rintro (h | ⟨-, h⟩)
  · exact absurd h (by decide +kernel)
  · exact absurd h (by decide +kernel)

/-- The instances of `Est.Holds`: the estimate `-2 ^ -46` with bound `2 ^ -46` holds of both
contracted results, and with bound 0 of the fused one; an estimate that is not valid holds of a
NaN. Its twins: with bound 0 it does not hold of the unfused result `+0`, and a valid one does not
hold of a NaN. -/
theorem est_inst :
    Est.Holds ⟨-(1 / 2 ^ 46), 1 / 2 ^ 46, true⟩ (ct 0) ∧
    Est.Holds ⟨-(1 / 2 ^ 46), 1 / 2 ^ 46, true⟩ (ct 1) ∧
    Est.Holds ⟨-(1 / 2 ^ 46), 0, true⟩ (ct 1) ∧
    ¬ Est.Holds ⟨-(1 / 2 ^ 46), 0, true⟩ (ct 0) ∧
    Est.Holds ⟨0, 0, false⟩ (f32 0x7fc00000) ∧
    ¬ Est.Holds ⟨0, 0, true⟩ (f32 0x7fc00000) := by
  have f0 := Model.Algebraic.isFinite_of_toRat?_eq_some ct_vals.1
  have f1 := Model.Algebraic.isFinite_of_toRat?_eq_some ct_vals.2
  have r0 := Model.Algebraic.toReal_of_toRat?_eq_some ct_vals.1
  have r1 := Model.Algebraic.toReal_of_toRat?_eq_some ct_vals.2
  refine ⟨fun _ => ⟨f0, ?_⟩, fun _ => ⟨f1, ?_⟩, fun _ => ⟨f1, ?_⟩, fun h => ?_,
    fun h => absurd h Bool.false_ne_true, fun h => ?_⟩
  · rw [r0, abs_le]
    constructor <;> norm_num
  · rw [r1, abs_le]
    constructor <;> norm_num
  · rw [r1, abs_le]
    constructor <;> norm_num
  · have := (abs_le.1 (h rfl).2).2
    rw [r0] at this
    norm_num at this
  · exact absurd (h rfl).1 (by decide +kernel)

/-- The values of `ct`'s operands, its product (which rounds to 1), `-1` and the factors
`1 + 2 ^ -23`, `1 - 2 ^ -23`, and of the largest finite binary32 number, `posMaxFinite` and its
word `0x7f7fffff`, by evaluation. -/
theorem ct_operands : (Model.mul (f32 0x3f800001) (f32 0x3f7ffffe)).toRat? = some 1 ∧
    (f32 0xbf800000).toRat? = some (-1) ∧ (f32 0x3f800001).toRat? = some (1 + 1 / 2 ^ 23) ∧
    (f32 0x3f7ffffe).toRat? = some (1 - 1 / 2 ^ 23) ∧
    (Model.posMaxFinite .binary32).toRat? = some ((2 ^ 24 - 1) * 2 ^ 104) ∧
    (f32 0x7f7fffff).toRat? = some ((2 ^ 24 - 1) * 2 ^ 104) := by
  decide +kernel

/-- **The instance of `floatBin_contract_est`** (and `contract_est`): `fadd contract` of the
product `(1 + 2 ^ -23) (1 - 2 ^ -23)`, with its factors, and `-1` gives `ct n` for the oracle
numbers 0, 1 and 2 (unfused, fused, unfused), by evaluation. Its estimate is valid, with the value
`-2 ^ -46`, the exact `(1 + 2 ^ -23) (1 - 2 ^ -23) - 1`, so each `ct n` is finite and within the
estimate's bound of `-2 ^ -46`. -/
theorem contract_est_inst {n : Nat} (hn : n < 3) :
    floatBin .float .fadd { contract := true }
        (.ofFloat .float (Model.mul (f32 0x3f800001) (f32 0x3f7ffffe)))
        (.ofFloat .float (f32 0xbf800000))
        (some (.ofFloat .float (f32 0x3f800001), .ofFloat .float (f32 0x3f7ffffe))) none n =
      .ok (.ofFloat .float (ct n)) ∧
    (Est.contract false (Model.mul (f32 0x3f800001) (f32 0x3f7ffffe)) (f32 0xbf800000)
        (some (f32 0x3f800001, f32 0x3f7ffffe)) none).valid = true ∧
    (Est.contract false (Model.mul (f32 0x3f800001) (f32 0x3f7ffffe)) (f32 0xbf800000)
        (some (f32 0x3f800001, f32 0x3f7ffffe)) none).value = -(1 / 2 ^ 46) ∧
    (ct n).isFinite = true ∧
    |(ct n).toReal - -(1 / 2 ^ 46)| ≤
      (Est.contract false (Model.mul (f32 0x3f800001) (f32 0x3f7ffffe)) (f32 0xbf800000)
        (some (f32 0x3f800001, f32 0x3f7ffffe)) none).bound := by
  have hb : floatBin .float .fadd { contract := true }
      (.ofFloat .float (Model.mul (f32 0x3f800001) (f32 0x3f7ffffe)))
      (.ofFloat .float (f32 0xbf800000))
      (some (.ofFloat .float (f32 0x3f800001), .ofFloat .float (f32 0x3f7ffffe))) none n =
      .ok (.ofFloat .float (ct n)) := by
    obtain _ | _ | _ | n := n
    · rfl
    · rfl
    · rfl
    · omega
  obtain ⟨h1, h2, h3, h4, h5, -⟩ := ct_operands
  have hv : (Est.contract false (Model.mul (f32 0x3f800001) (f32 0x3f7ffffe)) (f32 0xbf800000)
      (some (f32 0x3f800001, f32 0x3f7ffffe)) none).valid = true := by
    simp only [Est.contract, exact, decide_eq_true_eq,
      Model.Algebraic.toReal_of_toRat?_eq_some h1, Model.Algebraic.toReal_of_toRat?_eq_some h2,
      Model.Algebraic.toReal_of_toRat?_eq_some h3, Model.Algebraic.toReal_of_toRat?_eq_some h4,
      Model.Algebraic.isFinite_of_toRat?_eq_some h1, Model.Algebraic.isFinite_of_toRat?_eq_some h2,
      Model.Algebraic.toReal_of_toRat?_eq_some h5]
    norm_num [abs_le]
  have hx : (Est.contract false (Model.mul (f32 0x3f800001) (f32 0x3f7ffffe)) (f32 0xbf800000)
      (some (f32 0x3f800001, f32 0x3f7ffffe)) none).value = -(1 / 2 ^ 46) := by
    simp only [Est.contract, exact, Model.Algebraic.toReal_of_toRat?_eq_some h2,
      Model.Algebraic.toReal_of_toRat?_eq_some h3, Model.Algebraic.toReal_of_toRat?_eq_some h4]
    norm_num
  obtain ⟨f, e⟩ := floatBin_contract_est (t := .float) (op := .fadd) (.inl rfl) rfl
    (pa := some (f32 0x3f800001, f32 0x3f7ffffe)) (pb := none)
    (fun _ _ h hx => by cases h; exact ⟨hx, rfl⟩) (fun _ _ h => by cases h) hb hv
  exact ⟨hb, hv, hx, f, hx ▸ e⟩

/-- **The twin of `Est.contract`'s validity flag**: `fadd contract` of the largest finite binary32
number with itself, with no factors, gives `+∞` for oracle number 0, by evaluation. Its estimate
is not valid, and the same value and bound with the flag set do not hold of `+∞`, which is not
finite: without the range condition the row would claim a finite result. -/
theorem contract_est_twin :
    floatBin .float .fadd { contract := true } (.ofFloat .float (f32 0x7f7fffff))
        (.ofFloat .float (f32 0x7f7fffff)) none none 0 =
      .ok (.ofFloat .float (f32 0x7f800000)) ∧
    (Est.contract false (f32 0x7f7fffff) (f32 0x7f7fffff) none none).valid = false ∧
    ¬ Est.Holds ⟨(Est.contract false (f32 0x7f7fffff) (f32 0x7f7fffff) none none).value,
      (Est.contract false (f32 0x7f7fffff) (f32 0x7f7fffff) none none).bound, true⟩
      (f32 0x7f800000) := by
  obtain ⟨-, -, -, -, h5, h6⟩ := ct_operands
  refine ⟨rfl, ?_, fun h => absurd (h rfl).1 (by decide +kernel)⟩
  simp only [Est.contract, exact, decide_eq_false_iff_not,
    Model.Algebraic.toReal_of_toRat?_eq_some h5, Model.Algebraic.toReal_of_toRat?_eq_some h6,
    Model.Algebraic.isFinite_of_toRat?_eq_some h6]
  norm_num [abs_le]

/-- The instances of `maxnum_of_not_nan`: for every oracle number, `maxnum` of 1 and 2 is 2, and
of a quiet NaN and 1 is 1. Its twin for the premise "not both NaNs" (the one on signaling NaNs is
`nanEq_inst`'s pair `mx 1`, `mx 0`): `maxnum` of the quiet NaNs `0x7fc00000` and `0x7fc00001` under
the oracle numbers `2 * 0x7fc00000` and `2 * 0x7fc00001` gives the different NaNs `0x7fc00000` and
`0x7fc00001`. -/
theorem maxnum_inst :
    (∀ n, maxnum true (f32 0x3f800000) (f32 0x40000000) n = f32 0x40000000) ∧
    (∀ n, maxnum true (f32 0x7fc00000) (f32 0x3f800000) n = f32 0x3f800000) ∧
    maxnum true (f32 0x7fc00000) (f32 0x7fc00001) (2 * 0x7fc00000) = f32 0x7fc00000 ∧
    maxnum true (f32 0x7fc00000) (f32 0x7fc00001) (2 * 0x7fc00001) = f32 0x7fc00001 ∧
    f32 0x7fc00000 ≠ f32 0x7fc00001 := by
  refine ⟨fun n => ?_, fun n => ?_, by decide +kernel, by decide +kernel, by decide +kernel⟩
  · rw [maxnum_of_not_nan (by decide +kernel) (.inl (by decide +kernel))]
    decide +kernel
  · rw [maxnum_of_not_nan (by decide +kernel) (.inr (by decide +kernel))]
    decide +kernel

/-- The instance of `maxnum_nanEq`: `mx 1` and `mx 0xff800003`, under oracle numbers of one parity,
are related by `NaNEq` and are two different NaNs, so the coupled row gives `NaNEq` and not
equality. Its twin, of the coupling, is `nanEq_inst`'s pair `mx 1`, `mx 0`. -/
theorem maxnum_coupled :
    NaNEq (mx 1) (mx 0xff800003) ∧ mx 1 ≠ mx 0xff800003 ∧ (mx 1).isNaN = true ∧
      (mx 0xff800003).isNaN = true :=
  ⟨maxnum_nanEq true _ _ rfl, by decide +kernel, by decide +kernel, by decide +kernel⟩

/-- `llvm.maxnum` with no flags on the binary32 scalars of the words `a` and `b`, under context `c`
and scope `s`. -/
def mxI (c : Ctx) (s : Scope) (a b : Nat) : Except Fault (Option (Option Val × Mem)) :=
  intrinsic c s {} (.fminmax true (.fp .float)) [.ofFloat .float (f32 a), .ofFloat .float (f32 b)]

/-- For every context, scope `s` and words, `mxI` gives the scalar of `maxnum` of the words at
`s`'s oracle number 0, and leaves `s`'s memory (`intrinsic_fminmax_ofFloat`). -/
theorem mxI_eq (c : Ctx) (s : Scope) (a b : Nat) :
    mxI c s a b =
      .ok (some (some (.ofFloat .float (maxnum true (f32 a) (f32 b) (s.ch 0))), s.mem)) := by
  rw [mxI, intrinsic_fminmax_ofFloat (ft := .float) rfl (f32 a) (f32 b),
    withFlags_some (fm := {}) rfl rfl]
  rfl

/-- The instances of `fminmax_of_not_nan` and `fminmax_nanEq`: for every context and scope `s`,
`llvm.maxnum` of 1 and 2 is 2, leaving `s`'s memory; and for every scope `s'` whose oracle number
0 has the parity of `s`'s, `llvm.maxnum` of a signaling NaN and 1 under `s` and `s'` gives results
related by `Val.Lift .float NaNEq`. -/
theorem fminmax_inst (c : Ctx) {s s' : Scope} :
    mxI c s 0x3f800000 0x40000000 = .ok (some (some (.ofFloat .float (f32 0x40000000)), s.mem)) ∧
    (s.ch 0 % 2 = s'.ch 0 % 2 → Except.Rel (Option.Rel fun r r' =>
        Option.Rel (Val.Lift .float NaNEq) r.1 r'.1 ∧ r.2 = s.mem ∧ r'.2 = s'.mem)
      (mxI c s 0x7fa00000 0x3f800000) (mxI c s' 0x7fa00000 0x3f800000)) := by
  refine ⟨?_, fun h => ?_⟩
  · rw [mxI, fminmax_of_not_nan (ft := .float) (a := f32 0x3f800000) (b := f32 0x40000000) rfl
      (by decide +kernel) (.inl (by decide +kernel)), withFlags_some (fm := {}) rfl rfl]
    have e : Model.maximumNumber (f32 0x3f800000) (f32 0x40000000) = f32 0x40000000 := by
      decide +kernel
    exact congrArg (fun w => Except.ok (some (some (Val.ofFloat .float w), s.mem))) e
  · exact fminmax_nanEq (fm := {}) rfl rfl true (ft := .float) rfl (f32 0x7fa00000)
      (f32 0x3f800000) c c h

/-- The twins of `fminmax_of_not_nan`'s premise "not both NaNs" and of `fminmax_nanEq`'s
coupling: for every context, under scopes `s` and `s'` whose oracle numbers 0 are `2 * 0x7fc00000`
and `2 * 0x7fc00001`, `llvm.maxnum` of the quiet NaNs `0x7fc00000` and `0x7fc00001` gives the
scalars of the different NaNs `0x7fc00000` and `0x7fc00001` (`maxnum_inst`); under scopes `u` and
`u'` whose oracle numbers 0 are 1 and 0, of different parities, `llvm.maxnum` of a signaling NaN
and 1 gives the scalars of `mx 1` and `mx 0`, which `NaNEq` does not relate (`nanEq_inst`). -/
theorem fminmax_twin (c : Ctx) {s s' u u' : Scope} (h : s.ch 0 = 2 * 0x7fc00000)
    (h' : s'.ch 0 = 2 * 0x7fc00001) (k : u.ch 0 = 1) (k' : u'.ch 0 = 0) :
    mxI c s 0x7fc00000 0x7fc00001 = .ok (some (some (.ofFloat .float (f32 0x7fc00000)), s.mem)) ∧
    mxI c s' 0x7fc00000 0x7fc00001 =
      .ok (some (some (.ofFloat .float (f32 0x7fc00001)), s'.mem)) ∧
    f32 0x7fc00000 ≠ f32 0x7fc00001 ∧
    mxI c u 0x7fa00000 0x3f800000 = .ok (some (some (.ofFloat .float (mx 1)), u.mem)) ∧
    mxI c u' 0x7fa00000 0x3f800000 = .ok (some (some (.ofFloat .float (mx 0)), u'.mem)) ∧
    ¬ NaNEq (mx 1) (mx 0) := by
  obtain ⟨-, -, e, e', hne⟩ := maxnum_inst
  refine ⟨?_, ?_, hne, ?_, ?_, nanEq_inst.2⟩
  · rw [mxI_eq, h]
    exact congrArg (fun w => Except.ok (some (some (Val.ofFloat .float w), s.mem))) e
  · rw [mxI_eq, h']
    exact congrArg (fun w => Except.ok (some (some (Val.ofFloat .float w), s'.mem))) e'
  · rw [mxI_eq, k]
    rfl
  · rw [mxI_eq, k']
    rfl

/-- The words of 1 and `1 + 2 ^ -22`. -/
theorem one_vals : (f32 0x3f800000).toRat? = some 1 ∧
    (f32 0x3f800002).toRat? = some (4194305 / 4194304) := by
  decide +kernel

/-- The instance of `rsqrt_close` and `RsqrtClose`: the oracle numbers `0x3f800000` and `0x3f800001`
give the two different words of 1 and `1 + 2 ^ -23` as `rsqrt.approx` of 1, both close at 1. The
twin: the word of `1 + 2 ^ -22` is not close at 1. -/
theorem rsqrt_inst :
    rsqrt (f32 0x3f800000) 0x3f800000 = f32 0x3f800000 ∧
    rsqrt (f32 0x3f800000) 0x3f800001 = f32 0x3f800001 ∧ f32 0x3f800000 ≠ f32 0x3f800001 ∧
    RsqrtClose (f32 0x3f800000).toReal (f32 0x3f800000) ∧
    RsqrtClose (f32 0x3f800000).toReal (f32 0x3f800001) ∧
    ¬ RsqrtClose (f32 0x3f800000).toReal (f32 0x3f800002) := by
  have h0 : rsqrt (f32 0x3f800000) 0x3f800000 = f32 0x3f800000 := by decide +kernel
  have h1 : rsqrt (f32 0x3f800000) 0x3f800001 = f32 0x3f800001 := by decide +kernel
  have hf : (f32 0x3f800000).isFinite = true := by decide +kernel
  have hz : (f32 0x3f800000).isZero = false := by decide +kernel
  have hs : (f32 0x3f800000).isSubnormal = false := by decide +kernel
  have hp : (f32 0x3f800000).signBit = false := by decide +kernel
  have c0 := rsqrt_close hf hz hs hp 0x3f800000
  have c1 := rsqrt_close hf hz hs hp 0x3f800001
  rw [h0] at c0
  rw [h1] at c1
  refine ⟨h0, h1, by decide +kernel, c0, c1, fun ⟨_, h⟩ => ?_⟩
  have := (abs_le.1 h).2
  rw [Model.Algebraic.toReal_of_toRat?_eq_some one_vals.1,
    Model.Algebraic.toReal_of_toRat?_eq_some one_vals.2] at this
  norm_num [rsqrtErr] at this

/-- The fallback on PTX's special operands: oracle numbers whose words miss the contract give
FloatLib's `Model.rSqrt` of the flushed operand, `+0` at `+∞` (the oracle's `-0` misses), `-∞` at
the negative subnormal `-2 ^ -149` and a NaN at `-1`. At 1 the oracle's `+0` misses, the fallback
is 1, and it meets the contract (`rsqrtOk_of_rsqrt`). -/
theorem rsqrt_special :
    rsqrt (f32 0x7f800000) 0x80000000 = f32 0 ∧
    rsqrt (f32 0x80000001) 0 = f32 0xff800000 ∧
    (rsqrt (f32 0xbf800000) 0).isNaN = true ∧
    rsqrtOk (f32 0x3f800000) (f32 0) = false ∧ rsqrt (f32 0x3f800000) 0 = f32 0x3f800000 ∧
    rsqrtOk (f32 0x3f800000) (rsqrt (f32 0x3f800000) 0) = true :=
  ⟨by decide +kernel, by decide +kernel, by decide +kernel, by decide +kernel, by decide +kernel,
    rsqrtOk_of_rsqrt _ _⟩

/-- The scalar of the binary32 word with bits `n`. -/
def sc (n : Nat) : Val := .ofFloat .float (f32 n)

/-- For every reflexive relation `R` on binary32 words, two scalars of binary32 words related by
`Val.Lift R` are words related by `R`. -/
theorem lift_ofFloat {R : Model .binary32 → Model .binary32 → Prop} (hR : ∀ a, R a a)
    {a a' : Model .binary32} (h : Val.Lift .float R (.ofFloat .float a) (.ofFloat .float a')) :
    R a a' := by
  have e : ∀ b b' : Model .binary32, Val.ofFloat .float b = .ofFloat .float b' → b = b' :=
    fun b b' h => Option.some.inj ((Val.float?_ofFloat .float b).symm.trans
      ((congrArg (Val.float? .float) h).trans (Val.float?_ofFloat .float b')))
  rcases h with h | ⟨b, b', h1, h2, h3⟩
  · rw [e a a' h]
    exact hR a'
  · rw [e a b h1, e a' b' h2]
    exact h3

/-- The instance of `floatOp_finEq` and `Respects`: `fadd` of `+∞` and 1 under oracle number 0 and
of a NaN and 1 under 5 give related results. The twin of the premise `nnan = false`: with `nnan`
they give `+∞` and poison, which are not related. The twin of the premise on the operator: `fdiv`
of 1 by `+∞` and by a NaN gives `+0` and a NaN, which are not related. -/
theorem row1_inst :
    Except.Rel (Val.Lift .float FinEq) (floatOp .float .fadd {} [sc 0x7f800000, sc 0x3f800000] 0)
      (floatOp .float .fadd {} [sc 0x7fc00000, sc 0x3f800000] 5) ∧
    floatOp .float .fadd { nnan := true } [sc 0x7f800000, sc 0x3f800000] 0 = .ok (sc 0x7f800000) ∧
    floatOp .float .fadd { nnan := true } [sc 0x7fc00000, sc 0x3f800000] 0 = .ok .poison ∧
    ¬ Val.Lift .float FinEq (sc 0x7f800000) .poison ∧
    floatOp .float .fdiv {} [sc 0x3f800000, sc 0x7f800000] 0 = .ok (sc 0) ∧
    floatOp .float .fdiv {} [sc 0x3f800000, sc 0x7fc00000] 0 = .ok (sc 0x7fc00000) ∧
    ¬ Val.Lift .float FinEq (sc 0) (sc 0x7fc00000) := by
  have inf : (!(f32 0x7f800000).isFinite) = true := by decide +kernel
  have nan : (!(f32 0x7fc00000).isFinite) = true := by decide +kernel
  refine ⟨floatOp_finEq .float (.inl rfl) rfl rfl _ _ 0 5
    (.cons (Or.inr ⟨_, _, rfl, rfl, Or.inr ⟨inf, nan⟩⟩) (.cons (Or.inl rfl) .nil)) trivial,
    rfl, rfl, ?_, rfl, rfl, ?_⟩
  · rintro (h | ⟨_, _, -, h, -⟩) <;> simp [sc, Val.ofFloat] at h
  · intro h
    rcases lift_ofFloat (R := FinEq) (fun _ => .inl rfl) h with h | ⟨h, -⟩
    · exact absurd h (by decide +kernel)
    · exact absurd h (by decide +kernel)

/-- `llvm.maxnum` with no flags, at `<2 x float>`, on the vectors of the binary32 words `as` and
`bs`, under context `c` and scope `s`. -/
def mxV (c : Ctx) (s : Scope) (as bs : List (Model .binary32)) :
    Except Fault (Option (Option Val × Mem)) :=
  intrinsic c s {} (.fminmax true (.vec 2 (.fp .float)))
    [.vec (as.map (.ofFloat .float)), .vec (bs.map (.ofFloat .float))]

/-- For every context, scope `s` and two words per operand, `mxV` gives the vector whose lane `j`
is the scalar of `maxnum` of the lane's words at `s`'s oracle number `j`, and leaves `s`'s memory
(`intrinsic_fminmax_vec`). -/
theorem mxV_eq (c : Ctx) (s : Scope) (a0 a1 b0 b1 : Model .binary32) :
    mxV c s [a0, a1] [b0, b1] = .ok (some (some (.vec [.ofFloat .float (maxnum true a0 b0 (s.ch 0)),
      .ofFloat .float (maxnum true a1 b1 (s.ch 1))]), s.mem)) := by
  refine (intrinsic_fminmax_vec (max := true) (t := .vec 2 (.fp .float)) (ft := .float)
    (as := [a0, a1]) (bs := [b0, b1]) rfl rfl c s {}).trans ?_
  rfl

/-- The instance of `fminmax_vec_of_not_nan`: for every context and scope `s`, `llvm.maxnum` of
the vectors `<1, qNaN>` and `<2, 1>`, whose lanes have no signaling NaN and not two NaNs, is
`<2, 1>`, leaving `s`'s memory. -/
theorem fminmax_vec_inst (c : Ctx) (s : Scope) :
    mxV c s [f32 0x3f800000, f32 0x7fc00000] [f32 0x40000000, f32 0x3f800000] =
      .ok (some (some (.vec [sc 0x40000000, sc 0x3f800000]), s.mem)) := by
  refine (fminmax_vec_of_not_nan (max := true) (t := .vec 2 (.fp .float)) (ft := .float)
    (as := [f32 0x3f800000, f32 0x7fc00000]) (bs := [f32 0x40000000, f32 0x3f800000]) rfl rfl
    (fun a b h => ?_) c s {}).trans ?_
  · obtain _ | ⟨_, _ | ⟨_, h⟩⟩ := h
    · decide +kernel
    · decide +kernel
    · cases h
  · have e : (Model.maximumNumber (f32 0x3f800000) (f32 0x40000000),
        Model.maximumNumber (f32 0x7fc00000) (f32 0x3f800000)) =
        (f32 0x40000000, f32 0x3f800000) := by
      decide +kernel
    exact congrArg (fun p : Model .binary32 × Model .binary32 =>
      Except.ok (some (some (Val.vec [.ofFloat .float p.1, .ofFloat .float p.2]), s.mem))) e

/-- The instance of `fminmax_vec_nanEq`: for every context and scopes `s`, `s'` whose oracle
numbers 0 and 1 have one parity each, `llvm.maxnum` of the vectors `<sNaN, 1>` and `<1, 2>` under
`s` and `s'` gives vectors whose lanes are related by `Val.Lift .float NaNEq`, each call leaving
its scope's memory. -/
theorem fminmax_vec_coupled (c : Ctx) {s s' : Scope} (h0 : s.ch 0 % 2 = s'.ch 0 % 2)
    (h1 : s.ch 1 % 2 = s'.ch 1 % 2) :
    ∃ xs ys,
      mxV c s [f32 0x7fa00000, f32 0x3f800000] [f32 0x3f800000, f32 0x40000000] =
        .ok (some (some (.vec xs), s.mem)) ∧
      mxV c s' [f32 0x7fa00000, f32 0x3f800000] [f32 0x3f800000, f32 0x40000000] =
        .ok (some (some (.vec ys), s'.mem)) ∧
      List.Forall₂ (Val.Lift .float NaNEq) xs ys :=
  fminmax_vec_nanEq (fm := {}) rfl rfl true (ft := .float) (as := [f32 0x7fa00000, f32 0x3f800000])
    (bs := [f32 0x3f800000, f32 0x40000000]) rfl rfl c c fun j hj => by
    obtain _ | _ | j := j
    exacts [h0, h1, absurd hj (Nat.not_lt.2 (Nat.le_add_left 2 j))]

/-- The twins of `fminmax_vec_nanEq`'s coupling lane by lane and of `fminmax_vec_of_not_nan`'s
premise "no lane has two NaN operands". For every context, under scopes `u` and `u'` whose oracle
numbers 0 are both 0 (the scalar row's premise holds) and whose oracle numbers 1 are 1 and 0,
`llvm.maxnum` of `<1, sNaN>` and `<2, 1>` gives `<2, mx 1>` and `<2, mx 0>`, whose lanes 1
`Val.Lift .float NaNEq` does not relate (`nanEq_inst`); under scopes `s` and `s'` whose oracle
numbers 0 are `2 * 0x7fc00000` and `2 * 0x7fc00001`, `llvm.maxnum` of `<0x7fc00000, 1>` and
`<0x7fc00001, 2>` gives lanes 0 that are the different NaNs `0x7fc00000` and `0x7fc00001`
(`maxnum_inst`). -/
theorem fminmax_vec_twin (c : Ctx) {u u' s s' : Scope} (k0 : u.ch 0 = 0) (k0' : u'.ch 0 = 0)
    (k1 : u.ch 1 = 1) (k1' : u'.ch 1 = 0) (h : s.ch 0 = 2 * 0x7fc00000)
    (h' : s'.ch 0 = 2 * 0x7fc00001) :
    mxV c u [f32 0x3f800000, f32 0x7fa00000] [f32 0x40000000, f32 0x3f800000] =
      .ok (some (some (.vec [sc 0x40000000, .ofFloat .float (mx 1)]), u.mem)) ∧
    mxV c u' [f32 0x3f800000, f32 0x7fa00000] [f32 0x40000000, f32 0x3f800000] =
      .ok (some (some (.vec [sc 0x40000000, .ofFloat .float (mx 0)]), u'.mem)) ∧
    ¬ List.Forall₂ (Val.Lift .float NaNEq) [sc 0x40000000, .ofFloat .float (mx 1)]
      [sc 0x40000000, .ofFloat .float (mx 0)] ∧
    mxV c s [f32 0x7fc00000, f32 0x3f800000] [f32 0x7fc00001, f32 0x40000000] =
      .ok (some (some (.vec [sc 0x7fc00000, sc 0x40000000]), s.mem)) ∧
    mxV c s' [f32 0x7fc00000, f32 0x3f800000] [f32 0x7fc00001, f32 0x40000000] =
      .ok (some (some (.vec [sc 0x7fc00001, sc 0x40000000]), s'.mem)) ∧
    f32 0x7fc00000 ≠ f32 0x7fc00001 := by
  obtain ⟨e2, -, e, e', hne⟩ := maxnum_inst
  refine ⟨?_, ?_, ?_, ?_, ?_, hne⟩
  · refine (mxV_eq c u _ _ _ _).trans ?_
    rw [k0, k1]
    exact congrArg (fun w => Except.ok (some (some (Val.vec [.ofFloat .float w,
      .ofFloat .float (mx 1)]), u.mem))) (e2 0)
  · refine (mxV_eq c u' _ _ _ _).trans ?_
    rw [k0', k1']
    exact congrArg (fun w => Except.ok (some (some (Val.vec [.ofFloat .float w,
      .ofFloat .float (mx 0)]), u'.mem))) (e2 0)
  · rintro (_ | ⟨-, _ | ⟨hl, -⟩⟩)
    exact nanEq_inst.2 (lift_ofFloat (fun _ => .inl rfl) hl)
  · refine (mxV_eq c s _ _ _ _).trans ?_
    rw [h]
    exact congrArg₂ (fun w w' => Except.ok (some (some
      (Val.vec [.ofFloat .float w, .ofFloat .float w']), s.mem))) e (e2 _)
  · refine (mxV_eq c s' _ _ _ _).trans ?_
    rw [h']
    exact congrArg₂ (fun w w' => Except.ok (some (some
      (Val.vec [.ofFloat .float w, .ofFloat .float w']), s'.mem))) e' (e2 _)

/-- **The instance of `floatOp_isNaN`**, T5's NaN row: `fadd` with no flags of a quiet NaN and 1,
and `fadd contract` of 1 and a signaling NaN, give NaNs, for every oracle number. -/
theorem nan_row_inst (k : Nat) :
    (∃ r, floatOp .float .fadd {} [sc 0x7fc00000, sc 0x3f800000] k = .ok (.ofFloat .float r) ∧
      r.isNaN = true) ∧
    ∃ r, floatOp .float .fadd { contract := true } [sc 0x3f800000, sc 0x7f800001] k =
      .ok (.ofFloat .float r) ∧ r.isNaN = true :=
  ⟨floatOp_isNaN .float (by decide) rfl rfl rfl (.inl (by decide +kernel)) k,
    floatOp_isNaN .float (by decide) rfl rfl rfl (.inr (by decide +kernel)) k⟩

/-- **The twins of `floatOp_isNaN`'s premises**, at oracle number 0. Of the NaN operand: `fadd` of
1 and 1 gives 2, not a NaN. Of `nnan = false`: `fadd nnan` of a quiet NaN and 1 is poison. Of
`ninf = false`: `fadd ninf` of a quiet NaN and `+∞` is poison. Of the flags `nsz`, `reassoc`,
`arcp` and `afn` unset: `fadd nsz` of a quiet NaN and 1 faults. Of the operator: `frem` of a quiet
NaN and 1 faults. -/
theorem nan_row_twin :
    floatOp .float .fadd {} [sc 0x3f800000, sc 0x3f800000] 0 = .ok (sc 0x40000000) ∧
    (f32 0x40000000).isNaN = false ∧
    floatOp .float .fadd { nnan := true } [sc 0x7fc00000, sc 0x3f800000] 0 = .ok .poison ∧
    floatOp .float .fadd { ninf := true } [sc 0x7fc00000, sc 0x7f800000] 0 = .ok .poison ∧
    floatOp .float .fadd { nsz := true } [sc 0x7fc00000, sc 0x3f800000] 0 =
      .error (.unsupported "fast-math flags nsz/reassoc/arcp/afn") ∧
    floatOp .float .frem {} [sc 0x7fc00000, sc 0x3f800000] 0 = .error (.unsupported "frem") :=
  ⟨rfl, by decide +kernel, row1_inst.2.2.1, rfl, rfl, rfl⟩

/-- **The instance of `floatOp_nanEq`**: `fadd` with no flags of the quiet NaN `0x7fc00000` and 1
under oracle number 0 and of the quiet NaN `0x7fc00001` and 1 under 5 give results related by
`Val.Lift .float NaNEq`. The twin of its operand relation: `fadd` of `+∞` and 1 and of a quiet NaN
and 1, whose operands `FinEq` relates and `NaNEq` does not, give `+∞` and a NaN, which `NaNEq` does
not relate. -/
theorem nanEq_row_inst :
    Except.Rel (Val.Lift .float NaNEq) (floatOp .float .fadd {} [sc 0x7fc00000, sc 0x3f800000] 0)
      (floatOp .float .fadd {} [sc 0x7fc00001, sc 0x3f800000] 5) ∧
    floatOp .float .fadd {} [sc 0x7f800000, sc 0x3f800000] 0 = .ok (sc 0x7f800000) ∧
    floatOp .float .fadd {} [sc 0x7fc00000, sc 0x3f800000] 0 = .ok (sc 0x7fc00000) ∧
    ¬ Val.Lift .float NaNEq (sc 0x7f800000) (sc 0x7fc00000) := by
  refine ⟨floatOp_nanEq .float (by decide) rfl rfl _ _ 0 5
    (.cons (Or.inr ⟨_, _, rfl, rfl, nanEq_inst.1⟩) (.cons (Or.inl rfl) .nil)) trivial,
    rfl, rfl, ?_⟩
  intro h
  rcases lift_ofFloat (R := NaNEq) (fun _ => .inl rfl) h with h | ⟨h, -⟩
  · exact absurd h (by decide +kernel)
  · exact absurd h (by decide +kernel)

end MojoProofTest.FloatRel
