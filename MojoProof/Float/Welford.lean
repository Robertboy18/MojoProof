import MojoProof.Float.Stats

/-!
# Welford's mean and variance along any tree (docs/proofs/float-welford.md)

A one-pass layer norm keeps a Welford state per partial result: a count word, a mean word and a
word for the sum of squared deviations from the mean. The states of single inputs merge along a
tree (each thread's loop, then the warp's butterfly rounds or a block's halvings), and the
variance is the last sum of squared deviations divided by the last count. `wmerge` is the merge
the compiled layer norm kernels execute, one IEEE operation per instruction
(tests/corpus/layernorm/ln_rowwise_warp_t1_r1_ax0_w1_bs128_1a9a768a.nvptx.ll, lines 250-268, the
first butterfly round; the other rounds repeat it): the count `na + nb`, the weight
`f = nb / maxnum (na + nb, 1)`, the difference `δ = μb - μa`, the mean `μa + δ · f` and the sum
`(Ma + Mb) + ((δ · δ) · na) · f`.

Definitions: `wmerge`, the merge; `addMul`, a contracted `fmul` / `fadd` pair, fused or not;
`wmergeC`, the merge with its two pairs fused or not (lines 263-264 contract the sum's product
`((δ · δ) · na) · f` into `(Ma + Mb) + …`, lines 266 and 268 the mean's `δ · f` into `μa + δ · f`);
`wsingle`, the state of one input; `welfordC`, a tree's state with a choice of contraction at
each node, and `welford`, its case without fused pairs; `wupdate`, the loop's step (the count at
line 116 and lines 148-156, again at lines 184-192), and `wloop`, the loop over a list of words
with a choice of contraction at each iteration; `wvar`, a tree's variance word; `welfStep` and
`welfErr`, the error bounds. A choice is a pair of booleans, the mean's pair fused or not and the
sum's: LLVM's `contract` flag lets every pair be fused or not independently of the others, so the
bounds hold for every choice at every node and every iteration, and the uniform policies are the
constant choices.

Proved:
* `welford_error`, in every IEEE format, for every tree over any index type with at most `2 ^ p`
  leaves (`p` the format's precision) and every bound `B` on the inputs' magnitudes: if the
  tree's three words are finite, the count word is exactly the number of leaves, the mean word is
  within `(welfErr u η B d).1` of the leaves' mean and the sum word within
  `n · (welfErr u η B d).2` of their sum of squared deviations, `d` the tree's depth.
* `welfordC_error`, the same bounds for every choice of contraction at each node (each of the
  merge's two pairs fused or not, a fused pair being one rounding of the exact `c + a · b`);
  `welford_error` is its case without fused pairs.
* `wmean_error` and `wvar_error`, its corollaries over the indices `0, …, n - 1`: the mean word
  against `𝔼 j, x j` and the variance word, with FloatLib's mixed error `(u, (1 + u) · g + η)`,
  against TorchLean's population variance `TorchLean.var`.
* `wloop_error`, the loop over every list of at most `2 ^ p` words, for every choice of
  contraction at each iteration: the count word is the length `l` and the two other words are
  within `welfordC_error`'s bounds at depth `l - 1`.

These bounds are about Welford's merge and loop. The two-pass mean and variance (`mean_error`,
`var_error`, MojoProof/Float/Stats.lean) are another algorithm. The bounds are in terms of `B`, not
of the inputs' spread: `welfErr` grows with the depth like `d · u · B` for the mean and
`d² · u · B²` for the sum, to first order. Not covered: merges with an empty state (count `0`, a
thread without inputs), and the loop composed with the merges after it. Nothing is claimed when a
word is infinite or a NaN. The instances are in MojoProofTest/FloatWelford.lean.
-/

namespace MojoProof.Float

open FloatLib.Numerics FloatLib.Floats FloatLib.Floats.Formats
  FloatLib.Floats.Formats.BinaryInterchange
open scoped BigOperators

variable {fmt : FloatFormat}

/-- The merge of two Welford states `(count, mean, sum of squared deviations)`, as the compiled
layer norm kernels execute it without fused multiply-adds: with `δ = μb - μa` (`Model.sub`) and
`f = nb / maxnum (na + nb, 1)` (`Model.div` of `Model.maximumNumber`, LLVM's `maxnum`), the state
`(na + nb, μa + δ · f, (Ma + Mb) + ((δ · δ) · na) · f)`, each operation FloatLib's IEEE one. -/
def wmerge (a b : Model fmt × Model fmt × Model fmt) : Model fmt × Model fmt × Model fmt :=
  let δ := Model.sub b.2.1 a.2.1
  let f := Model.div b.1 (Model.maximumNumber (Model.add a.1 b.1) (Model.posOne fmt))
  (Model.add a.1 b.1, Model.add a.2.1 (Model.mul δ f),
    Model.add (Model.add a.2.2 b.2.2) (Model.mul (Model.mul (Model.mul δ δ) a.1) f))

/-- The word `c + a · b` of a contracted `fmul` / `fadd` pair: one `Model.fma a b c` when
`fused`, else `Model.add c (Model.mul a b)`, each operation FloatLib's IEEE one. -/
def addMul (fused : Bool) (c a b : Model fmt) : Model fmt :=
  if fused then Model.fma a b c else Model.add c (Model.mul a b)

/-- The merge `wmerge` with each of its two contracted `fmul` / `fadd` pairs fused or not, as the
compiled kernels may execute it: the count `na + nb`, the mean `addMul fm μa δ f` and the sum
`addMul fv (Ma + Mb) ((δ · δ) · na) f`, with `δ` and `f` as in `wmerge`; `wmergeC false false`
is `wmerge`. -/
def wmergeC (fm fv : Bool) (a b : Model fmt × Model fmt × Model fmt) :
    Model fmt × Model fmt × Model fmt :=
  let δ := Model.sub b.2.1 a.2.1
  let f := Model.div b.1 (Model.maximumNumber (Model.add a.1 b.1) (Model.posOne fmt))
  (Model.add a.1 b.1, addMul fm a.2.1 δ f,
    addMul fv (Model.add a.2.2 b.2.2) (Model.mul (Model.mul δ δ) a.1) f)

/-- The Welford state of one input word `x`: count `1`, mean `x`, sum of squared deviations
`+0`. -/
def wsingle (x : Model fmt) : Model fmt × Model fmt × Model fmt :=
  (Model.posOne fmt, x, Model.posZero fmt)

/-- The Welford state of the words `x` at the leaves of a tree `t`, for every choice `c` of
contraction at each node: `wsingle` at every leaf, and at the node at position `p` (the path from
the root, `false` for a left and `true` for a right child) the merge `wmergeC (c p).1 (c p).2`,
the mean's pair fused or not by `(c p).1` and the sum's by `(c p).2`. A constant `c` is a uniform
policy. -/
def welfordC {ι : Type} :
    (List Bool → Bool × Bool) → ReductionTree ι → (ι → Model fmt) →
      Model fmt × Model fmt × Model fmt
  | _, .leaf j, x => wsingle (x j)
  | c, .node a b, x =>
    wmergeC (c []).1 (c []).2 (welfordC (c ∘ List.cons false) a x)
      (welfordC (c ∘ List.cons true) b x)

/-- The Welford state of the words `x` at the leaves of a tree `t` without fused pairs:
`welfordC` at the constant choice `(false, false)`, so `wmerge` at every node (`wmergeC false
false` is `wmerge`) and `wsingle` at every leaf. -/
def welford {ι : Type} (t : ReductionTree ι) (x : ι → Model fmt) :
    Model fmt × Model fmt × Model fmt :=
  welfordC (fun _ => (false, false)) t x

/-- One step of Welford's loop, as the compiled layer norm kernels' loop executes it: from the
state `(n, μ, M)` and the word `x`, the count `c = n + 1`, `δ = x - μ`, the weight `f = 1 / c`, the
mean `μ + δ · f` and the sum `M + ((δ · δ) · n) · f`, with the mean's pair fused or not (`fm`) and
the sum's (`fv`), each operation FloatLib's IEEE one. -/
def wupdate (fm fv : Bool) (a : Model fmt × Model fmt × Model fmt) (x : Model fmt) :
    Model fmt × Model fmt × Model fmt :=
  let c := Model.add a.1 (Model.posOne fmt)
  let δ := Model.sub x a.2.1
  let f := Model.div (Model.posOne fmt) c
  (c, addMul fm a.2.1 δ f, addMul fv a.2.2 (Model.mul (Model.mul δ δ) a.1) f)

/-- Welford's loop over the words `xs` in order, for every choice `c` of contraction at each
iteration: from the state `(+0, +0, +0)`, iteration `i` (from `0`) applies
`wupdate (c i).1 (c i).2` to the state and the word `xs[i]`. A constant `c` is a uniform
policy. -/
def wloop (c : ℕ → Bool × Bool) (xs : List (Model fmt)) : Model fmt × Model fmt × Model fmt :=
  xs.zipIdx.foldl (fun a y => wupdate (c y.2).1 (c y.2).2 a y.1)
    (Model.posZero fmt, Model.posZero fmt, Model.posZero fmt)

/-- The variance word of `welford t x`: its sum of squared deviations divided by its count
(`Model.div`). -/
def wvar {ι : Type} (t : ReductionTree ι) (x : ι → Model fmt) : Model fmt :=
  Model.div (welford t x).2.2 (welford t x).1

/-- One merge's error bounds `(e', g')` from its operands' `(e, g) = p`, with unit roundoff `u`,
underflow allowance `η` and input bound `B`: an operand's mean word within `e` of its mean and its
sum word within `count · g` of its sum of squared deviations give the merged mean word within
`e'` and the merged sum word within `count · g'`. With `A = 2B + 2e`, `ε = uA + η` and
`F = 1 + u + η`: `e' = (1 + u) (e + u (A + ε) F + η + ε F + A (u + η)) + u B + η`; with
`q = u (A + ε)² + η + (2e + ε) (A + ε + 2B)` and `s = q + u (4B² + q) + η`:
`g' = (1 + u) (g + u (B² + g) + η + u (4B² + s) F + η + s F + 4B² (u + η)) + u B² + η`. -/
noncomputable def welfStep (u η B : ℝ) (p : ℝ × ℝ) : ℝ × ℝ :=
  let A := 2 * B + 2 * p.1
  let ε := u * A + η
  let F := 1 + (u + η)
  let q := u * ((A + ε) * (A + ε)) + η + (2 * p.1 + ε) * (A + ε + 2 * B)
  let s := q + u * (4 * B ^ 2 + q) + η
  ((1 + u) * (p.1 + (u * ((A + ε) * F) + η + (ε * F + A * (u + η)))) + u * B + η,
    (1 + u) * (p.2 + u * (B ^ 2 + p.2) + η + (u * ((4 * B ^ 2 + s) * F) + η + (s * F +
      4 * B ^ 2 * (u + η)))) + u * B ^ 2 + η)

/-- The error bounds of `welford_error` for a tree of depth `d`: `(0, 0)` at depth `0`, then
`welfStep` once per level. -/
noncomputable def welfErr (u η B : ℝ) : ℕ → ℝ × ℝ
  | 0 => (0, 0)
  | d + 1 => welfStep u η B (welfErr u η B d)

/-- `|a · b - a₀ · b₀| ≤ |a - a₀| · |b| + |a₀| · |b - b₀|`. -/
private theorem abs_mul_sub_mul (a a₀ b b₀ : ℝ) :
    |a * b - a₀ * b₀| ≤ |a - a₀| * |b| + |a₀| * |b - b₀| := by
  rw [show a * b - a₀ * b₀ = (a - a₀) * b + a₀ * (b - b₀) by ring, ← abs_mul, ← abs_mul]
  exact abs_add_le _ _

/-- A word equal to the rounding of `t` is within `u · |t| + η` of `t`. -/
private theorem rnd {x : Model fmt} {t : ℝ} (h : x.toReal = Model.roundAt fmt t) :
    |x.toReal - t| ≤ Model.unitRoundoffAt fmt * |t| + Model.underflowErrorAt fmt := by
  rw [h]
  exact (Model.mixedError_roundAt fmt t).bound

/-- A finite word `addMul fused c a b`: its three operands are finite and, for a real `P` within
FloatLib's rounding error of `a · b` (`a · b` itself when fused), the word is within the rounding
error of `c + P`. -/
private theorem addMul_round (hfmt : fmt.isIEEE = true) (fused : Bool) {c a b : Model fmt}
    (h : (addMul fused c a b).isFinite = true) :
    c.isFinite = true ∧ a.isFinite = true ∧ b.isFinite = true ∧ ∃ P : ℝ,
      |P - a.toReal * b.toReal| ≤
        Model.unitRoundoffAt fmt * |a.toReal * b.toReal| + Model.underflowErrorAt fmt ∧
      |(addMul fused c a b).toReal - (c.toReal + P)| ≤
        Model.unitRoundoffAt fmt * |c.toReal + P| + Model.underflowErrorAt fmt := by
  cases fused
  · simp only [addMul, Bool.false_eq_true, ↓reduceIte] at h ⊢
    obtain ⟨hc, hp⟩ := Model.isFinite_of_isFinite_add hfmt h
    obtain ⟨ha, hb⟩ := Model.isFinite_of_isFinite_mul hfmt hp
    exact ⟨hc, ha, hb, _, rnd (Model.toReal_mul_eq_roundAt _ _ hfmt hp),
      rnd (Model.toReal_add_eq_roundAt _ _ hfmt h)⟩
  · simp only [addMul, ↓reduceIte] at h ⊢
    obtain ⟨ha, hb, hc⟩ := Model.isFinite_of_isFinite_fma hfmt h
    refine ⟨hc, ha, hb, a.toReal * b.toReal, ?_, ?_⟩
    · rw [sub_self, abs_zero]
      exact add_nonneg (mul_nonneg (Model.unitRoundoffAt_pos fmt).le (abs_nonneg _))
        (Model.underflowErrorAt_pos fmt).le
    · exact rnd (by rw [Model.toReal_fma_eq_roundAt _ _ _ hfmt h, add_comm])

/-- One merge's mean: exact means `ma`, `mb` and weight `f ∈ [0, 1]`, mean words `xa`, `xb`
within `p.1` of them, and the roundings `F` of `f`, `D` of `xb - xa`, `P` of `D · F` and `m` of
`xa + P` give `m` within `(welfStep u η B p).1` of `ma + (mb - ma) · f`. -/
private theorem mean_step {u η B ma mb xa xb f F D P m : ℝ} (p : ℝ × ℝ) (hu : 0 ≤ u)
    (hη : 0 ≤ η) (hf0 : 0 ≤ f) (hf1 : f ≤ 1) (hma : |ma| ≤ B) (hmb : |mb| ≤ B)
    (hm : |ma + (mb - ma) * f| ≤ B) (ea : |xa - ma| ≤ p.1) (eb : |xb - mb| ≤ p.1)
    (rF : |F - f| ≤ u * |f| + η) (rD : |D - (xb - xa)| ≤ u * |xb - xa| + η)
    (rP : |P - D * F| ≤ u * |D * F| + η) (rm : |m - (xa + P)| ≤ u * |xa + P| + η) :
    |m - (ma + (mb - ma) * f)| ≤ (welfStep u η B p).1 := by
  obtain ⟨e, g⟩ := p
  dsimp only at ea eb
  simp only [welfStep]
  have he : 0 ≤ e := (abs_nonneg _).trans ea
  have hB : 0 ≤ B := (abs_nonneg _).trans hma
  generalize hA : 2 * B + 2 * e = A
  generalize hε : u * A + η = ε
  generalize hF : 1 + (u + η) = F'
  have hA0 : 0 ≤ A := by rw [← hA]; positivity
  have hε0 : 0 ≤ ε := by rw [← hε]; positivity
  obtain ⟨a1, a2⟩ := abs_le.1 ea
  obtain ⟨b1, b2⟩ := abs_le.1 eb
  obtain ⟨c1, c2⟩ := abs_le.1 hma
  obtain ⟨d1, d2⟩ := abs_le.1 hmb
  have hx : |xb - xa| ≤ A := abs_le.2 ⟨by linarith, by linarith⟩
  have hD1 : |D - (xb - xa)| ≤ ε := by
    have := mul_le_mul_of_nonneg_left hx hu
    linarith
  have hD : |D| ≤ A + ε := by
    have := abs_sub_abs_le_abs_sub D (xb - xa)
    linarith
  rw [abs_of_nonneg hf0] at rF
  have huf := mul_le_mul_of_nonneg_left hf1 hu
  have hFf : |F - f| ≤ u + η := by linarith
  have hF' : |F| ≤ F' := by
    have := abs_sub_abs_le_abs_sub F f
    rw [abs_of_nonneg hf0] at this
    linarith
  have h1 : |D * F - (xb - xa) * f| ≤ ε * F' + A * (u + η) := by
    have k1 := abs_mul_sub_mul D (xb - xa) F f
    have k2 := mul_le_mul hD1 hF' (abs_nonneg _) hε0
    have k3 := mul_le_mul hx hFf (abs_nonneg _) hA0
    linarith
  have hDF : |D * F| ≤ (A + ε) * F' := by
    rw [abs_mul]
    exact mul_le_mul hD hF' (abs_nonneg _) (by linarith)
  have hK : |xa + P - (ma + (mb - ma) * f)| ≤
      e + (u * ((A + ε) * F') + η + (ε * F' + A * (u + η))) := by
    rw [show xa + P - (ma + (mb - ma) * f) =
      ((xa - ma) * (1 - f) + (xb - mb) * f) + ((P - D * F) + (D * F - (xb - xa) * f)) by ring]
    have k1 := abs_add_le ((xa - ma) * (1 - f) + (xb - mb) * f)
      ((P - D * F) + (D * F - (xb - xa) * f))
    have k2 := abs_add_le ((xa - ma) * (1 - f)) ((xb - mb) * f)
    have k3 := abs_add_le (P - D * F) (D * F - (xb - xa) * f)
    rw [abs_mul, abs_mul, abs_of_nonneg (sub_nonneg.2 hf1), abs_of_nonneg hf0] at k2
    have k4 := mul_le_mul_of_nonneg_right ea (sub_nonneg.2 hf1)
    have k5 := mul_le_mul_of_nonneg_right eb hf0
    have k6 := mul_le_mul_of_nonneg_left hDF hu
    linarith
  have hxP : |xa + P| ≤ B + (e + (u * ((A + ε) * F') + η + (ε * F' + A * (u + η)))) := by
    have := abs_sub_abs_le_abs_sub (xa + P) (ma + (mb - ma) * f)
    linarith
  have k7 := abs_sub_le m (xa + P) (ma + (mb - ma) * f)
  have k8 := mul_le_mul_of_nonneg_left hxP hu
  linarith

/-- One merge's sum of squared deviations: with `mean_step`'s inputs, counts `na, nb ≥ 1`, exact
sums `Da`, `Db` and sum words `Ya`, `Yb` within `na · p.2`, `nb · p.2` of them, and the roundings
`Q` of `D · D`, `S` of `Q · na`, `T` of `S · F`, `W` of `Ya + Yb` and `M` of `W + T`, the word `M`
is within `(na + nb) · (welfStep u η B p).2` of `Da + Db + (mb - ma)² · na · f`. -/
private theorem dev_step {u η B ma mb xa xb f F D na nb Da Db Ya Yb Q S T W M : ℝ} (p : ℝ × ℝ)
    (hu : 0 ≤ u) (hη : 0 ≤ η) (hf0 : 0 ≤ f) (hf1 : f ≤ 1) (hna : 1 ≤ na) (hnb : 1 ≤ nb)
    (hma : |ma| ≤ B) (hmb : |mb| ≤ B) (hDa : |Da| ≤ na * B ^ 2) (hDb : |Db| ≤ nb * B ^ 2)
    (hM : |Da + Db + (mb - ma) * (mb - ma) * na * f| ≤ (na + nb) * B ^ 2)
    (ea : |xa - ma| ≤ p.1) (eb : |xb - mb| ≤ p.1) (ga : |Ya - Da| ≤ na * p.2)
    (gb : |Yb - Db| ≤ nb * p.2)
    (rF : |F - f| ≤ u * |f| + η) (rD : |D - (xb - xa)| ≤ u * |xb - xa| + η)
    (rQ : |Q - D * D| ≤ u * |D * D| + η) (rS : |S - Q * na| ≤ u * |Q * na| + η)
    (rT : |T - S * F| ≤ u * |S * F| + η) (rW : |W - (Ya + Yb)| ≤ u * |Ya + Yb| + η)
    (rM : |M - (W + T)| ≤ u * |W + T| + η) :
    |M - (Da + Db + (mb - ma) * (mb - ma) * na * f)| ≤ (na + nb) * (welfStep u η B p).2 := by
  obtain ⟨e, g⟩ := p
  dsimp only at ea eb ga gb
  simp only [welfStep]
  have he : 0 ≤ e := (abs_nonneg _).trans ea
  have hB : 0 ≤ B := (abs_nonneg _).trans hma
  have hna0 : 0 ≤ na := by linarith
  have hnb0 : 0 ≤ nb := by linarith
  have hη1 : η ≤ na * η := by
    have := mul_nonneg (sub_nonneg.2 hna) hη
    linarith
  have hη2 : η ≤ (na + nb) * η := by
    have := mul_nonneg hnb0 hη
    linarith
  generalize hA : 2 * B + 2 * e = A
  generalize hε : u * A + η = ε
  generalize hF : 1 + (u + η) = F'
  generalize hq : u * ((A + ε) * (A + ε)) + η + (2 * e + ε) * (A + ε + 2 * B) = q
  generalize hs : q + u * (4 * B ^ 2 + q) + η = s
  generalize ht : u * ((4 * B ^ 2 + s) * F') + η + (s * F' + 4 * B ^ 2 * (u + η)) = t
  have hA0 : 0 ≤ A := by rw [← hA]; positivity
  have hε0 : 0 ≤ ε := by rw [← hε]; positivity
  have hF0 : 0 ≤ F' := by rw [← hF]; positivity
  have hq0 : 0 ≤ q := by rw [← hq]; positivity
  have hs0 : 0 ≤ s := by rw [← hs]; positivity
  have ht0 : 0 ≤ t := by rw [← ht]; positivity
  obtain ⟨a1, a2⟩ := abs_le.1 ea
  obtain ⟨b1, b2⟩ := abs_le.1 eb
  obtain ⟨c1, c2⟩ := abs_le.1 hma
  obtain ⟨d1, d2⟩ := abs_le.1 hmb
  have hx : |xb - xa| ≤ A := abs_le.2 ⟨by linarith, by linarith⟩
  have hD1 : |D - (xb - xa)| ≤ ε := by
    have := mul_le_mul_of_nonneg_left hx hu
    linarith
  have hD : |D| ≤ A + ε := by
    have := abs_sub_abs_le_abs_sub D (xb - xa)
    linarith
  have hδ : |mb - ma| ≤ 2 * B := abs_le.2 ⟨by linarith, by linarith⟩
  have hDδ : |D - (mb - ma)| ≤ 2 * e + ε := by
    have k1 : |xb - xa - (mb - ma)| ≤ 2 * e := abs_le.2 ⟨by linarith, by linarith⟩
    have k2 := abs_sub_le D (xb - xa) (mb - ma)
    linarith
  have hDp : |D + (mb - ma)| ≤ A + ε + 2 * B := by
    have := abs_add_le D (mb - ma)
    linarith
  have hδδ : |(mb - ma) * (mb - ma)| ≤ 4 * B ^ 2 := by
    rw [abs_mul]
    have := mul_le_mul hδ hδ (abs_nonneg _) (by linarith)
    linarith
  have hQ1 : |Q - (mb - ma) * (mb - ma)| ≤ q := by
    have k1 := abs_sub_le Q (D * D) ((mb - ma) * (mb - ma))
    have k2 : |D * D| ≤ (A + ε) * (A + ε) := by
      rw [abs_mul]
      exact mul_le_mul hD hD (abs_nonneg _) (by linarith)
    have k3 : |D * D - (mb - ma) * (mb - ma)| ≤ (2 * e + ε) * (A + ε + 2 * B) := by
      rw [show D * D - (mb - ma) * (mb - ma) = (D - (mb - ma)) * (D + (mb - ma)) by ring,
        abs_mul]
      exact mul_le_mul hDδ hDp (abs_nonneg _) (by linarith)
    have k4 := mul_le_mul_of_nonneg_left k2 hu
    linarith
  have hQ : |Q| ≤ 4 * B ^ 2 + q := by
    have := abs_sub_abs_le_abs_sub Q ((mb - ma) * (mb - ma))
    linarith
  have hX : |(mb - ma) * (mb - ma) * na| ≤ 4 * B ^ 2 * na := by
    rw [abs_mul _ na, abs_of_nonneg hna0]
    exact mul_le_mul_of_nonneg_right hδδ hna0
  have hS1 : |S - (mb - ma) * (mb - ma) * na| ≤ na * s := by
    have k1 := abs_sub_le S (Q * na) ((mb - ma) * (mb - ma) * na)
    have k2 : |Q * na| ≤ (4 * B ^ 2 + q) * na := by
      rw [abs_mul, abs_of_nonneg hna0]
      exact mul_le_mul_of_nonneg_right hQ hna0
    have k3 : |Q * na - (mb - ma) * (mb - ma) * na| ≤ q * na := by
      rw [← sub_mul, abs_mul, abs_of_nonneg hna0]
      exact mul_le_mul_of_nonneg_right hQ1 hna0
    have k4 := mul_le_mul_of_nonneg_left k2 hu
    rw [← hs]
    linarith
  have hS : |S| ≤ na * (4 * B ^ 2 + s) := by
    have := abs_sub_abs_le_abs_sub S ((mb - ma) * (mb - ma) * na)
    linarith
  rw [abs_of_nonneg hf0] at rF
  have huf := mul_le_mul_of_nonneg_left hf1 hu
  have hFf : |F - f| ≤ u + η := by linarith
  have hF' : |F| ≤ F' := by
    have := abs_sub_abs_le_abs_sub F f
    rw [abs_of_nonneg hf0] at this
    linarith
  have hT1 : |T - (mb - ma) * (mb - ma) * na * f| ≤ na * t := by
    have k1 := abs_sub_le T (S * F) ((mb - ma) * (mb - ma) * na * f)
    have k2 : |S * F| ≤ na * (4 * B ^ 2 + s) * F' := by
      rw [abs_mul]
      exact mul_le_mul hS hF' (abs_nonneg _) (by positivity)
    have k3 := abs_mul_sub_mul S ((mb - ma) * (mb - ma) * na) F f
    have k4 := mul_le_mul hS1 hF' (abs_nonneg _) (by positivity)
    have k5 := mul_le_mul hX hFf (abs_nonneg _) (by positivity)
    have k6 := mul_le_mul_of_nonneg_left k2 hu
    rw [← ht]
    linarith
  have hW1 : |W - (Da + Db)| ≤ (na + nb) * (g + u * (B ^ 2 + g) + η) := by
    have k1 := abs_sub_le W (Ya + Yb) (Da + Db)
    have k2 : |Ya + Yb - (Da + Db)| ≤ na * g + nb * g := by
      rw [show Ya + Yb - (Da + Db) = (Ya - Da) + (Yb - Db) by ring]
      have := abs_add_le (Ya - Da) (Yb - Db)
      linarith
    have k3 : |Ya + Yb| ≤ (na + nb) * (B ^ 2 + g) := by
      have := abs_sub_abs_le_abs_sub (Ya + Yb) (Da + Db)
      have := abs_add_le Da Db
      linarith
    have k4 := mul_le_mul_of_nonneg_left k3 hu
    linarith
  have hK : |W + T - (Da + Db + (mb - ma) * (mb - ma) * na * f)| ≤
      (na + nb) * (g + u * (B ^ 2 + g) + η + t) := by
    rw [show W + T - (Da + Db + (mb - ma) * (mb - ma) * na * f) =
      (W - (Da + Db)) + (T - (mb - ma) * (mb - ma) * na * f) by ring]
    have := abs_add_le (W - (Da + Db)) (T - (mb - ma) * (mb - ma) * na * f)
    have := mul_nonneg hnb0 ht0
    linarith
  have hWT : |W + T| ≤ (na + nb) * B ^ 2 + (na + nb) * (g + u * (B ^ 2 + g) + η + t) := by
    have := abs_sub_abs_le_abs_sub (W + T) (Da + Db + (mb - ma) * (mb - ma) * na * f)
    linarith
  have k1 := abs_sub_le M (W + T) (Da + Db + (mb - ma) * (mb - ma) * na * f)
  have k2 := mul_le_mul_of_nonneg_left hWT hu
  linarith

/-- Inputs within `B` in magnitude: their sum is within `l · B` and their sum of squares in
`[0, l · B²]`, `l` the number of inputs. -/
private theorem list_bound {ι : Type} (y : ι → ℝ) {B : ℝ} (L : List ι)
    (hB : ∀ j ∈ L, |y j| ≤ B) :
    |(L.map y).sum| ≤ L.length * B ∧ 0 ≤ (L.map fun j => y j ^ 2).sum ∧
      (L.map fun j => y j ^ 2).sum ≤ L.length * B ^ 2 := by
  induction L with
  | nil => simp
  | cons j L ih =>
    obtain ⟨h1, h2, h3⟩ := ih fun i hi => hB i (List.mem_cons_of_mem _ hi)
    have hj := hB j List.mem_cons_self
    have k1 := abs_add_le (y j) (L.map y).sum
    have k2 : y j ^ 2 ≤ B ^ 2 := by
      rw [← sq_abs]
      exact pow_le_pow_left₀ (abs_nonneg _) hj 2
    simp only [List.map_cons, List.sum_cons, List.length_cons]
    push_cast
    exact ⟨by linarith, by positivity, by linarith⟩

/-- A sum `S1` within `l · B` and a sum of squares `S2 ∈ [0, l · B²]` of `l > 0` inputs: the mean
`S1 / l` is within `B` and `S2 - S1² / l` within `l · B²` in magnitude. -/
private theorem stats_bound {S1 S2 l B : ℝ} (hl : 0 < l) (h1 : |S1| ≤ l * B) (h2 : 0 ≤ S2)
    (h3 : S2 ≤ l * B ^ 2) : |S1 / l| ≤ B ∧ |S2 - S1 ^ 2 / l| ≤ l * B ^ 2 := by
  constructor
  · rw [abs_div, abs_of_pos hl, div_le_iff₀ hl]
    linarith
  · have k1 : S1 ^ 2 ≤ (l * B) ^ 2 := by
      rw [← sq_abs]
      exact pow_le_pow_left₀ (abs_nonneg _) h1 2
    have k2 : S1 ^ 2 / l ≤ l * B ^ 2 := by
      rw [div_le_iff₀ hl]
      linarith
    have k3 : 0 ≤ S1 ^ 2 / l := by positivity
    rw [abs_le]
    constructor <;> linarith

/-- The mean of two parts with counts `la, lb > 0` and sums `S1a`, `S1b`, as the merge computes
it. -/
private theorem merge_mean {S1a S1b la lb : ℝ} (ha : 0 < la) (hb : 0 < lb) :
    (S1a + S1b) / (la + lb) = S1a / la + (S1b / lb - S1a / la) * (lb / (la + lb)) := by
  have := ha.ne'
  have := hb.ne'
  have : la + lb ≠ 0 := by positivity
  field_simp
  ring

/-- The sum of squared deviations of two parts with counts `la, lb > 0`, sums `S1a`, `S1b` and
sums of squares `S2a`, `S2b`, as the merge computes it. -/
private theorem merge_dev {S1a S1b S2a S2b la lb : ℝ} (ha : 0 < la) (hb : 0 < lb) :
    S2a + S2b - (S1a + S1b) ^ 2 / (la + lb) = (S2a - S1a ^ 2 / la) + (S2b - S1b ^ 2 / lb) +
      (S1b / lb - S1a / la) * (S1b / lb - S1a / la) * la * (lb / (la + lb)) := by
  have := ha.ne'
  have := hb.ne'
  have : la + lb ≠ 0 := by positivity
  field_simp
  ring

/-- `welfErr`'s two bounds are nonnegative. -/
private theorem welfErr_nonneg {u η B : ℝ} (hu : 0 ≤ u) (hη : 0 ≤ η) (hB : 0 ≤ B) (d : ℕ) :
    0 ≤ (welfErr u η B d).1 ∧ 0 ≤ (welfErr u η B d).2 := by
  induction d with
  | zero => simp [welfErr]
  | succ d ih =>
    obtain ⟨h1, h2⟩ := ih
    simp only [welfErr, welfStep]
    constructor <;> positivity

/-- **Welford's merge along any tree, with or without fused multiply-adds.** In every IEEE
format, for every choice `c` of contraction at each node (`(c p).1` for the mean's `fmul` / `fadd`
pair at the node at position `p`, `(c p).2` for the sum's, each independently of the other nodes),
every tree `t` over any index type with at most `2 ^ p` leaves (`p = fmt.fracWidth + 1` the
precision), words `x`, bound `B` on the leaves' `|x j|` and `d` at least the tree's depth: if the
three words of `welfordC c t x` are finite, the count word is the number of leaves `l`, the
mean word is within `(welfErr u η B d).1` of the leaves' mean `Σ x j / l` and the sum word within
`l · (welfErr u η B d).2` of their sum of squared deviations `Σ x j² - (Σ x j)² / l`, `u` and `η`
FloatLib's unit roundoff and underflow allowance. The bounds do not depend on `c`. Each operation
is FloatLib's rounding (`Model.mixedError_roundAt`), a fused pair one rounding of the exact
`y + a · b`; the counts are
integers below `2 ^ p`, so exact (`Model.roundAt_intCast_of_abs_le`). Covers Welford's merge only,
not the two-pass `mean_error` and `var_error`, nor the loop (`wloop_error`). Nothing is claimed
when a word is infinite or a NaN. -/
theorem welfordC_error (hfmt : fmt.isIEEE = true) (c : List Bool → Bool × Bool) {ι : Type}
    (t : ReductionTree ι) (x : ι → Model fmt) {B : ℝ} (hB : ∀ j ∈ t.leaves, |(x j).toReal| ≤ B)
    (hn : t.leaves.length ≤ 2 ^ (fmt.fracWidth + 1)) {d : ℕ} (hd : t.depth ≤ d)
    (h₁ : (welfordC c t x).1.isFinite = true) (h₂ : (welfordC c t x).2.1.isFinite = true)
    (h₃ : (welfordC c t x).2.2.isFinite = true) :
    (welfordC c t x).1.toReal = t.leaves.length ∧
      |(welfordC c t x).2.1.toReal -
          (t.leaves.map fun j => (x j).toReal).sum / t.leaves.length| ≤
        (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B d).1 ∧
      |(welfordC c t x).2.2.toReal - ((t.leaves.map fun j => (x j).toReal ^ 2).sum -
          (t.leaves.map fun j => (x j).toReal).sum ^ 2 / t.leaves.length)| ≤
        t.leaves.length *
          (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B d).2 := by
  have hu := (Model.unitRoundoffAt_pos fmt).le
  have hη := (Model.underflowErrorAt_pos fmt).le
  have hone := Model.isFinite_posOne fmt
  suffices key : ∀ (s : ReductionTree ι) (c : List Bool → Bool × Bool) (d : ℕ), s.depth ≤ d →
      (∀ j ∈ s.leaves, |(x j).toReal| ≤ B) → s.leaves.length ≤ 2 ^ (fmt.fracWidth + 1) →
      (welfordC c s x).1.isFinite = true → (welfordC c s x).2.1.isFinite = true →
      (welfordC c s x).2.2.isFinite = true →
      (welfordC c s x).1.toReal = s.leaves.length ∧
      |(welfordC c s x).2.1.toReal -
          (s.leaves.map fun j => (x j).toReal).sum / s.leaves.length| ≤
        (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B d).1 ∧
      |(welfordC c s x).2.2.toReal - ((s.leaves.map fun j => (x j).toReal ^ 2).sum -
          (s.leaves.map fun j => (x j).toReal).sum ^ 2 / s.leaves.length)| ≤
        s.leaves.length *
          (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B d).2 from
    key t c d hd hB hn h₁ h₂ h₃
  intro s
  induction s with
  | leaf j =>
    intro c d _ hB _ _ _ _
    have hB0 : 0 ≤ B := (abs_nonneg _).trans (hB j List.mem_cons_self)
    obtain ⟨k1, k2⟩ := welfErr_nonneg hu hη hB0 d
    refine ⟨?_, ?_, ?_⟩ <;> simp [welfordC, wsingle,
      ReductionTree.leaves, Model.toReal_posOne, Model.toReal_posZero, k1, k2]
  | node ta tb iha ihb =>
    intro c d hd hB hn h1 h2 h3
    simp only [ReductionTree.depth] at hd
    obtain ⟨d, rfl⟩ : ∃ d', d = d' + 1 := ⟨d - 1, by omega⟩
    have hBa : ∀ j ∈ ta.leaves, |(x j).toReal| ≤ B := fun j hj =>
      hB j (List.mem_append_left _ hj)
    have hBb : ∀ j ∈ tb.leaves, |(x j).toReal| ≤ B := fun j hj =>
      hB j (List.mem_append_right _ hj)
    have hn' : ta.leaves.length + tb.leaves.length ≤ 2 ^ (fmt.fracWidth + 1) := by
      simpa [ReductionTree.leaves] using hn
    have hw : welfordC c (.node ta tb) x = wmergeC (c []).1 (c []).2
        (welfordC (c ∘ List.cons false) ta x) (welfordC (c ∘ List.cons true) tb x) := rfl
    have iha := iha (c ∘ List.cons false)
    have ihb := ihb (c ∘ List.cons true)
    generalize welfordC (c ∘ List.cons false) ta x = wa at iha hw
    generalize welfordC (c ∘ List.cons true) tb x = wb at ihb hw
    rw [hw] at h1 h2 h3 ⊢
    simp only [wmergeC] at h1 h2 h3 ⊢
    obtain ⟨hca, hcb⟩ := Model.isFinite_of_isFinite_add hfmt h1
    obtain ⟨hxa, hδ, hf, P, rP, rm⟩ := addMul_round hfmt _ h2
    have hxb := (Model.isFinite_of_isFinite_sub hfmt hδ).1
    obtain ⟨hW, hS, -, T, rT, rM⟩ := addMul_round hfmt _ h3
    obtain ⟨hYa, hYb⟩ := Model.isFinite_of_isFinite_add hfmt hW
    have hQ := (Model.isFinite_of_isFinite_mul hfmt hS).1
    obtain ⟨ca, ea, ga⟩ := iha d (by omega) hBa (le_trans (Nat.le_add_right _ _) hn') hca hxa hYa
    obtain ⟨cb, eb, gb⟩ := ihb d (by omega) hBb (le_trans (Nat.le_add_left _ _) hn') hcb hxb hYb
    have hla : (1 : ℝ) ≤ ta.leaves.length := by
      exact_mod_cast (show 1 ≤ ta.leaves.length by rw [ReductionTree.length_leaves]; omega)
    have hlb : (1 : ℝ) ≤ tb.leaves.length := by
      exact_mod_cast (show 1 ≤ tb.leaves.length by rw [ReductionTree.length_leaves]; omega)
    have hla0 : (0 : ℝ) < ta.leaves.length := by linarith
    have hlb0 : (0 : ℝ) < tb.leaves.length := by linarith
    have hc : (Model.add wa.1 wb.1).toReal =
        ta.leaves.length + tb.leaves.length := by
      rw [Model.toReal_add_eq_roundAt _ _ hfmt h1, ca, cb]
      have k := Model.roundAt_intCast_of_abs_le fmt
        (n := ((ta.leaves.length + tb.leaves.length : ℕ) : ℤ)) (by
          rw [Int.cast_natCast, abs_of_nonneg (Nat.cast_nonneg _)]
          exact_mod_cast hn')
      push_cast at k
      exact k
    have hν := Model.maximumNumber_eq_maximum_of_not_isNaN
      (Model.add wa.1 wb.1) (Model.posOne fmt)
      (Model.isNaN_eq_false_of_isFinite_eq_true _ h1)
      (Model.isNaN_eq_false_of_isFinite_eq_true _ hone)
    have hνf : (Model.maximumNumber (Model.add wa.1 wb.1)
        (Model.posOne fmt)).isFinite = true := by
      rw [hν]
      exact Model.isFinite_maximum _ _ h1 hone
    have hνr : (Model.maximumNumber (Model.add wa.1 wb.1)
        (Model.posOne fmt)).toReal = ta.leaves.length + tb.leaves.length := by
      rw [hν, Model.toReal_maximum_eq_max_of_isFinite _ _ h1 hone, hc,
        Model.toReal_posOne]
      exact max_eq_left (by linarith)
    have rF := rnd (Model.toReal_div_eq_roundAt _ _ hfmt hνf hf)
    rw [cb, hνr] at rF
    have rD := rnd (Model.toReal_sub_eq_roundAt _ _ hfmt hδ)
    have rQ := rnd (Model.toReal_mul_eq_roundAt _ _ hfmt hQ)
    have rS := rnd (Model.toReal_mul_eq_roundAt _ _ hfmt hS)
    rw [ca] at rS
    have rW := rnd (Model.toReal_add_eq_roundAt _ _ hfmt hW)
    have hf0 : (0 : ℝ) ≤ tb.leaves.length / (ta.leaves.length + tb.leaves.length) := by
      positivity
    have hf1 : (tb.leaves.length : ℝ) / (ta.leaves.length + tb.leaves.length) ≤ 1 :=
      (div_le_one (by linarith)).2 (by linarith)
    obtain ⟨sa1, sa2, sa3⟩ := list_bound (fun j => (x j).toReal) ta.leaves hBa
    obtain ⟨sb1, sb2, sb3⟩ := list_bound (fun j => (x j).toReal) tb.leaves hBb
    obtain ⟨ma, Da⟩ := stats_bound hla0 sa1 sa2 sa3
    obtain ⟨mb, Db⟩ := stats_bound hlb0 sb1 sb2 sb3
    have k1 := abs_add_le (ta.leaves.map fun j => (x j).toReal).sum
      (tb.leaves.map fun j => (x j).toReal).sum
    obtain ⟨mab, Dab⟩ := stats_bound (B := B) (S1 := (ta.leaves.map fun j => (x j).toReal).sum +
        (tb.leaves.map fun j => (x j).toReal).sum)
      (S2 := (ta.leaves.map fun j => (x j).toReal ^ 2).sum +
        (tb.leaves.map fun j => (x j).toReal ^ 2).sum)
      (add_pos hla0 hlb0) (by linarith) (by linarith) (by linarith)
    rw [merge_mean hla0 hlb0] at mab
    rw [merge_dev hla0 hlb0] at Dab
    simp only [ReductionTree.leaves, List.map_append, List.sum_append, List.length_append,
      Nat.cast_add, welfErr]
    refine ⟨hc, ?_, ?_⟩
    · rw [merge_mean hla0 hlb0]
      exact mean_step _ hu hη hf0 hf1 ma mb mab ea eb rF rD rP rm
    · rw [merge_dev hla0 hlb0]
      exact dev_step _ hu hη hf0 hf1 hla hlb ma mb Da Db Dab ea eb ga gb rF rD rQ rS rT rW rM

/-- **Welford's merge along any tree.** In every IEEE format, for every tree `t` over any index
type with at most `2 ^ p` leaves (`p = fmt.fracWidth + 1` the precision), words `x`, bound `B` on
the leaves' `|x j|` and `d` at least the tree's depth: if the three words of `welford t x` are
finite, the count word is the number of leaves `l`, the mean word is within `(welfErr u η B d).1`
of the leaves' mean `Σ x j / l` and the sum word within `l · (welfErr u η B d).2` of their sum of
squared deviations `Σ x j² - (Σ x j)² / l`, `u` and `η` FloatLib's unit roundoff and underflow
allowance. Each operation is FloatLib's rounding (`Model.mixedError_roundAt`); the counts are
integers below `2 ^ p`, so exact (`Model.roundAt_intCast_of_abs_le`). Covers Welford's merge only,
not the two-pass `mean_error` and `var_error`. Nothing is claimed when a word is infinite or a
NaN. `welfordC_error` at the constant choice `(false, false)`, no pair fused. -/
theorem welford_error (hfmt : fmt.isIEEE = true) {ι : Type} (t : ReductionTree ι)
    (x : ι → Model fmt) {B : ℝ} (hB : ∀ j ∈ t.leaves, |(x j).toReal| ≤ B)
    (hn : t.leaves.length ≤ 2 ^ (fmt.fracWidth + 1)) {d : ℕ} (hd : t.depth ≤ d)
    (h₁ : (welford t x).1.isFinite = true) (h₂ : (welford t x).2.1.isFinite = true)
    (h₃ : (welford t x).2.2.isFinite = true) :
    (welford t x).1.toReal = t.leaves.length ∧
      |(welford t x).2.1.toReal - (t.leaves.map fun j => (x j).toReal).sum / t.leaves.length| ≤
        (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B d).1 ∧
      |(welford t x).2.2.toReal - ((t.leaves.map fun j => (x j).toReal ^ 2).sum -
          (t.leaves.map fun j => (x j).toReal).sum ^ 2 / t.leaves.length)| ≤
        t.leaves.length *
          (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B d).2 :=
  welfordC_error hfmt (fun _ => (false, false)) t x hB hn hd h₁ h₂ h₃

/-- A finite word `addMul fused c a b` with `c` zero and `b` one is `a`. -/
private theorem addMul_zero_one (hfmt : fmt.isIEEE = true) (fused : Bool) {c a b : Model fmt}
    (h : (addMul fused c a b).isFinite = true) (hc : c.toReal = 0) (hb : b.toReal = 1) :
    (addMul fused c a b).toReal = a.toReal := by
  obtain ⟨-, ha, -, -⟩ := addMul_round hfmt fused h
  cases fused
  · simp only [addMul, Bool.false_eq_true, ↓reduceIte] at h ⊢
    have hp := (Model.isFinite_of_isFinite_add hfmt h).2
    rw [Model.toReal_add_eq_roundAt _ _ hfmt h, Model.toReal_mul_eq_roundAt _ _ hfmt hp, hc, hb,
      mul_one, Model.roundAt_toReal_eq _ ha, zero_add, Model.roundAt_toReal_eq _ ha]
  · simp only [addMul, ↓reduceIte] at h ⊢
    rw [Model.toReal_fma_eq_roundAt _ _ _ hfmt h, hc, hb, mul_one, add_zero,
      Model.roundAt_toReal_eq _ ha]

/-- **Welford's loop over a row, with or without fused multiply-adds.** In every IEEE format,
for every choice `c` of contraction at each iteration (`(c i).1` for the mean's `fmul` / `fadd`
pair at iteration `i`, `(c i).2` for the sum's, each independently of the other iterations), every
list `xs` of at most `2 ^ p` words (`p = fmt.fracWidth + 1` the precision) and bound `B` on their
`|x|`: if the three words of `wloop c xs` are finite, the count word is the length `l`, the mean
word is within `(welfErr u η B (l - 1)).1` of the mean `Σ x / l` and the sum word within
`l · (welfErr u η B (l - 1)).2` of the sum of squared deviations `Σ x² - (Σ x)² / l`, `u` and `η`
FloatLib's unit roundoff and underflow allowance: `welfordC_error`'s bounds at depth `l - 1`, each
step merging the state with one word. The bounds do not depend on `c`. The first step is exact.
Covers the loop's update over the words in the order it reads them, not the merges after the
loop. Nothing is claimed when a word is infinite or a NaN. -/
theorem wloop_error (hfmt : fmt.isIEEE = true) (c : ℕ → Bool × Bool) (xs : List (Model fmt))
    {B : ℝ} (hB : ∀ x ∈ xs, |x.toReal| ≤ B) (hn : xs.length ≤ 2 ^ (fmt.fracWidth + 1))
    (h₁ : (wloop c xs).1.isFinite = true) (h₂ : (wloop c xs).2.1.isFinite = true)
    (h₃ : (wloop c xs).2.2.isFinite = true) :
    (wloop c xs).1.toReal = xs.length ∧
      |(wloop c xs).2.1.toReal - (xs.map Model.toReal).sum / xs.length| ≤
        (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B (xs.length - 1)).1 ∧
      |(wloop c xs).2.2.toReal - ((xs.map fun x => x.toReal ^ 2).sum -
          (xs.map Model.toReal).sum ^ 2 / xs.length)| ≤ xs.length *
        (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B (xs.length - 1)).2 := by
  have hu := (Model.unitRoundoffAt_pos fmt).le
  have hη := (Model.underflowErrorAt_pos fmt).le
  have hone := Model.isFinite_posOne fmt
  induction xs using List.reverseRecOn with
  | nil => simp [wloop, welfErr]
  | append_singleton xs y ih =>
    have hw : wloop c (xs ++ [y]) = wupdate (c xs.length).1 (c xs.length).2 (wloop c xs) y := by
      simp only [wloop, List.zipIdx_append, List.zipIdx_singleton, List.foldl_append,
        List.foldl_cons, List.foldl_nil, Nat.zero_add]
    have hBy : |y.toReal| ≤ B := hB y (List.mem_append_right _ List.mem_cons_self)
    have hB0 : 0 ≤ B := (abs_nonneg _).trans hBy
    rw [hw] at h₁ h₂ h₃ ⊢
    simp only [wupdate] at h₁ h₂ h₃ ⊢
    obtain ⟨hca, -⟩ := Model.isFinite_of_isFinite_add hfmt h₁
    obtain ⟨hxa, hδ, hf, P, rP, rm⟩ := addMul_round hfmt _ h₂
    have hy := (Model.isFinite_of_isFinite_sub hfmt hδ).1
    obtain ⟨hYa, hS, -, T, rT, rM⟩ := addMul_round hfmt _ h₃
    have hQ := (Model.isFinite_of_isFinite_mul hfmt hS).1
    by_cases h0 : xs = []
    · subst h0
      have hz : wloop c ([] : List (Model fmt)) =
          (Model.posZero fmt, Model.posZero fmt, Model.posZero fmt) := rfl
      simp only [hz] at h₁ h₂ h₃ hδ hS ⊢
      have hc : (Model.add (Model.posZero fmt) (Model.posOne fmt)).toReal = 1 := by
        rw [Model.toReal_add_eq_roundAt _ _ hfmt h₁, Model.toReal_posZero, Model.toReal_posOne,
          zero_add, Model.roundAt_one]
      have hF : (Model.div (Model.posOne fmt)
          (Model.add (Model.posZero fmt) (Model.posOne fmt))).toReal = 1 := by
        rw [Model.toReal_div_eq_roundAt _ _ hfmt h₁ (by simpa [hz] using hf), hc,
          Model.toReal_posOne, div_one, Model.roundAt_one]
      have hD : (Model.sub y (Model.posZero fmt)).toReal = y.toReal := by
        rw [Model.toReal_sub_eq_roundAt _ _ hfmt hδ, Model.toReal_posZero, sub_zero,
          Model.roundAt_toReal_eq _ hy]
      have hS0 : (Model.mul (Model.mul (Model.sub y (Model.posZero fmt))
          (Model.sub y (Model.posZero fmt))) (Model.posZero fmt)).toReal = 0 := by
        rw [Model.toReal_mul_eq_roundAt _ _ hfmt hS, Model.toReal_posZero, mul_zero,
          Model.roundAt_zero]
      rw [addMul_zero_one hfmt _ h₂ (Model.toReal_posZero fmt) hF, hD,
        addMul_zero_one hfmt _ h₃ (Model.toReal_posZero fmt) hF, hS0, hc]
      simp [welfErr]
    obtain ⟨k, hk⟩ : ∃ k, xs.length = k + 1 :=
      ⟨xs.length - 1, by cases xs with | nil => exact absurd rfl h0 | cons _ _ => simp⟩
    have hn' : xs.length + 1 ≤ 2 ^ (fmt.fracWidth + 1) := by simpa using hn
    obtain ⟨ca, ea, ga⟩ := ih (fun x hx => hB x (List.mem_append_left _ hx)) (by omega) hca hxa
      hYa
    have hla : (1 : ℝ) ≤ xs.length := by exact_mod_cast (show 1 ≤ xs.length by omega)
    have hla0 : (0 : ℝ) < xs.length := by linarith
    have hc : (Model.add (wloop c xs).1 (Model.posOne fmt)).toReal = xs.length + 1 := by
      rw [Model.toReal_add_eq_roundAt _ _ hfmt h₁, ca, Model.toReal_posOne]
      have k := Model.roundAt_intCast_of_abs_le fmt (n := ((xs.length + 1 : ℕ) : ℤ)) (by
          rw [Int.cast_natCast, abs_of_nonneg (Nat.cast_nonneg _)]
          exact_mod_cast hn')
      push_cast at k
      exact k
    have rF := rnd (Model.toReal_div_eq_roundAt _ _ hfmt h₁ hf)
    rw [Model.toReal_posOne, hc] at rF
    have rD := rnd (Model.toReal_sub_eq_roundAt _ _ hfmt hδ)
    have rQ := rnd (Model.toReal_mul_eq_roundAt _ _ hfmt hQ)
    have rS := rnd (Model.toReal_mul_eq_roundAt _ _ hfmt hS)
    rw [ca] at rS
    have hf0 : (0 : ℝ) ≤ 1 / (xs.length + 1) := by positivity
    have hf1 : (1 : ℝ) / (xs.length + 1) ≤ 1 := (div_le_one (by positivity)).2 (by linarith)
    obtain ⟨sa1, sa2, sa3⟩ := list_bound Model.toReal xs fun x hx =>
      hB x (List.mem_append_left _ hx)
    have hy2 : y.toReal ^ 2 ≤ B ^ 2 := by
      rw [← sq_abs]
      exact pow_le_pow_left₀ (abs_nonneg _) hBy 2
    obtain ⟨ma, Da⟩ := stats_bound hla0 sa1 sa2 sa3
    obtain ⟨mb, Db⟩ := stats_bound (B := B) (S1 := y.toReal) (S2 := y.toReal ^ 2) (l := 1) one_pos
      (by rw [one_mul]; exact hBy) (sq_nonneg _) (by rw [one_mul]; exact hy2)
    have k1 := abs_add_le (xs.map Model.toReal).sum y.toReal
    obtain ⟨mab, Dab⟩ := stats_bound (B := B) (S1 := (xs.map Model.toReal).sum + y.toReal)
      (S2 := (xs.map fun x => x.toReal ^ 2).sum + y.toReal ^ 2) (l := xs.length + 1)
      (by linarith) (by linarith) (by linarith [sq_nonneg y.toReal]) (by linarith)
    rw [merge_mean hla0 one_pos] at mab
    rw [merge_dev hla0 one_pos] at Dab
    have p0 := welfErr_nonneg hu hη hB0 (xs.length - 1)
    have hE : welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B
        ((xs ++ [y]).length - 1) = welfStep (Model.unitRoundoffAt fmt)
          (Model.underflowErrorAt fmt) B
          (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B (xs.length - 1)) := by
      simp [hk, welfErr]
    rw [hE]
    simp only [List.map_append, List.map_cons, List.map_nil, List.sum_append, List.sum_cons,
      List.sum_nil, add_zero, List.length_append, List.length_cons, List.length_nil, zero_add,
      Nat.cast_add, Nat.cast_one]
    refine ⟨hc, ?_, ?_⟩
    · rw [merge_mean hla0 one_pos]
      exact mean_step _ hu hη hf0 hf1 ma mb mab ea (by rw [div_one, sub_self, abs_zero]; exact p0.1)
        rF rD rP rm
    · rw [merge_dev hla0 one_pos]
      exact dev_step (Yb := 0) _ hu hη hf0 hf1 hla le_rfl ma mb Da Db Dab ea
        (by rw [div_one, sub_self, abs_zero]; exact p0.1) ga
        (by rw [div_one, sub_self, sub_zero, abs_zero, one_mul]; exact p0.2) rF rD rQ rS rT
        (by rw [add_zero, sub_self, abs_zero]; positivity) rM

/-- A population variance over `0, …, n - 1`, `n > 0`, is `(Σ y j² - (Σ y j)² / n) / n`. -/
private theorem var_eq {n : ℕ} (hn : 0 < n) (y : Fin n → ℝ) :
    TorchLean.var y = (((List.finRange n).map fun j => y j ^ 2).sum -
      ((List.finRange n).map y).sum ^ 2 / n) / n := by
  rw [← Fin.sum_univ_def, ← Fin.sum_univ_def]
  have hn' : (n : ℝ) ≠ 0 := Nat.cast_ne_zero.2 hn.ne'
  simp only [TorchLean.var, Fintype.expect_eq_sum_div_card, Fintype.card_fin]
  have e : ∀ i, (y i - (∑ j, y j) / n) * (y i - (∑ j, y j) / n) =
      y i ^ 2 - 2 * ((∑ j, y j) / n) * y i + ((∑ j, y j) / n) ^ 2 := fun i => by ring
  simp only [e, Finset.sum_add_distrib, Finset.sum_sub_distrib, ← Finset.mul_sum,
    Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
  field_simp
  ring

/-- **Welford's mean against `𝔼`.** In every IEEE format, for every `n ≤ 2 ^ p` (`p` the
precision), tree `t` whose leaves are the indices `0, …, n - 1` up to order, words `x` and bound
`B` on every `|x j|`: if the three words of `welford t x` are finite, the mean word is within
`(welfErr u η B t.depth).1` of the exact mean `𝔼 j, x j` of the real values, `u` and `η`
FloatLib's unit roundoff and underflow allowance. `welford_error` at the tree's depth. Covers
Welford's merge only; the two-pass mean is `mean_error`. -/
theorem wmean_error (hfmt : fmt.isIEEE = true) {n : ℕ} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (x : Fin n → Model fmt) {B : ℝ}
    (hB : ∀ j, |(x j).toReal| ≤ B) (hn : n ≤ 2 ^ (fmt.fracWidth + 1))
    (h₁ : (welford t x).1.isFinite = true) (h₂ : (welford t x).2.1.isFinite = true)
    (h₃ : (welford t x).2.2.isFinite = true) :
    |(welford t x).2.1.toReal - 𝔼 j, (x j).toReal| ≤
      (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B t.depth).1 := by
  have hl := ht.length_eq
  rw [List.length_finRange] at hl
  obtain ⟨-, e, -⟩ := welford_error hfmt t x (fun j _ => hB j) (by rw [hl]; exact hn) le_rfl
    h₁ h₂ h₃
  rw [(ht.map fun j => (x j).toReal).sum_eq, hl] at e
  rw [Finset.expect_eq_sum_div_card, Finset.card_univ, Fintype.card_fin, Fin.sum_univ_def]
  exact e

/-- **Welford's variance against TorchLean's.** In every IEEE format, for every `n ≤ 2 ^ p` (`p`
the precision), tree `t` whose leaves are the indices `0, …, n - 1` up to order, words `x` and
bound `B` on every `|x j|`: if the three words of `welford t x` and the variance word
`wvar t x` are finite, the variance word approximates TorchLean's population variance
`TorchLean.var` of the real values with FloatLib's mixed error `(u, (1 + u) · g + η)`,
`g = (welfErr u η B t.depth).2`, `u` and `η` FloatLib's unit roundoff and underflow allowance.
`welford_error`, then FloatLib's `Model.mixedError_toReal_div` with the exact count. Covers
Welford's merge only; the two-pass variance is `var_error`. -/
theorem wvar_error (hfmt : fmt.isIEEE = true) {n : ℕ} (t : ReductionTree (Fin n))
    (ht : t.leaves.Perm (List.finRange n)) (x : Fin n → Model fmt) {B : ℝ}
    (hB : ∀ j, |(x j).toReal| ≤ B) (hn : n ≤ 2 ^ (fmt.fracWidth + 1))
    (h₁ : (welford t x).1.isFinite = true) (h₂ : (welford t x).2.1.isFinite = true)
    (h₃ : (welford t x).2.2.isFinite = true) (h : (wvar t x).isFinite = true) :
    MixedError (wvar t x).toReal (TorchLean.var fun j => (x j).toReal) (Model.unitRoundoffAt fmt)
      ((1 + Model.unitRoundoffAt fmt) *
          (welfErr (Model.unitRoundoffAt fmt) (Model.underflowErrorAt fmt) B t.depth).2 +
        Model.underflowErrorAt fmt) := by
  have hl := ht.length_eq
  rw [List.length_finRange] at hl
  obtain ⟨c, -, e⟩ := welford_error hfmt t x (fun j _ => hB j) (by rw [hl]; exact hn) le_rfl
    h₁ h₂ h₃
  rw [(ht.map fun j => (x j).toReal ^ 2).sum_eq, (ht.map fun j => (x j).toReal).sum_eq, hl] at e
  rw [hl] at c
  have hn0 : 0 < n := by
    rw [← hl, ReductionTree.length_leaves]
    omega
  have hn' : (n : ℝ) ≠ 0 := Nat.cast_ne_zero.2 hn0.ne'
  have hd := Model.mixedError_toReal_div hfmt h₁ h (MixedError.of_abs_sub_le e)
    (MixedError.of_eq c) zero_lt_one
  simp only [add_zero, zero_div, mul_zero, zero_add, sub_zero, one_mul, Nat.abs_cast] at hd
  rw [mul_div_cancel_left₀ _ hn'] at hd
  rw [var_eq hn0]
  exact hd

end MojoProof.Float
