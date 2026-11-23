import MojoProof.Layout.Basic

/-!
# The coordinate laws: crd2idx, cosize, idx2crd, reverse and affinity

The laws of docs/proofs/layout-laws.md about the coordinate map of MojoProof/Layout/Basic.lean,
for every shape and stride that satisfy each law's premises:

* `Lay.call_scalar`: a scalar coordinate below the size is split colexicographically, first mode
  fastest, and its offset is the dot product of the digits with the stride's leaves;
* `crd2idx_flat`, `Lay.call_leaves`, `Lay.call_flat` and `Lay.call_add`: a coordinate of one
  leaf per mode has as offset its dot product with the strides, whatever the extents, so on a
  flat layout the map is additive (the layout is affine);
* `Lay.cosize_eq` and `Lay.call_lt_cosize`: the cosize is one more than the sum of
  `(s - 1) * d` over the modes, and every scalar coordinate's offset lies below it;
* `idx2crd_call`: idx2crd inverts the coordinate map on a flat layout whose modes are nested
  (each mode's extent times stride divides every later stride), and `idx2crd_call_reverse` for
  the reverse order, which includes row-major layouts;
* `Lay.reverse_reverse`, `Lay.size_reverse` and `Lay.call_reverse`: reversal is an involution,
  keeps the size, and maps the reversed coordinate to the same offset.
-/

namespace MojoProof.Layout

open Tup

/-! ## Helpers on lists -/

/-- `colex` gives one digit per extent. -/
theorem colex_length (i : Nat) (ss : List Nat) : (colex i ss).length = ss.length := by
  induction ss generalizing i with
  | nil => rfl
  | cons s ss ih => simp [colex, ih]

/-- The digits of `i` against `A ++ B` are its digits against `A`, then the digits of
`i / A.prod` against `B`. For every `i`, `A` and `B`. -/
theorem colex_append (i : Nat) (A B : List Nat) :
    colex i (A ++ B) = colex i A ++ colex (i / A.prod) B := by
  induction A generalizing i with
  | nil => simp [colex]
  | cons a A ih => simp [colex, ih, Nat.div_div_eq_div_mul]

/-- The digits of `i` against `A` depend only on `i % A.prod`. For every `i` and `A`. -/
theorem colex_mod (i : Nat) (A : List Nat) : colex (i % A.prod) A = colex i A := by
  induction A generalizing i with
  | nil => rfl
  | cons a A ih =>
    simp only [colex, List.prod_cons, Nat.mod_mul_right_mod, Nat.mod_mul_right_div_self, ih]

/-- The sum of a pointwise product over appended lists splits when the first parts have equal
lengths. -/
theorem sum_zipWith_append (a b c d : List Nat) (h : a.length = c.length) :
    (List.zipWith (· * ·) (a ++ b) (c ++ d)).sum =
      (List.zipWith (· * ·) a c).sum + (List.zipWith (· * ·) b d).sum := by
  rw [List.zipWith_append h, List.sum_append]

/-- Congruent lists of trees have equal lengths. -/
theorem congruentL_length : ∀ (ss ds : List Tup), congruentL ss ds = true → ss.length = ds.length
  | [], [], _ => rfl
  | _ :: ss, _ :: ds, h => by
    simp only [congruentL, Bool.and_eq_true] at h
    simp [congruentL_length ss ds h.2]
  | [], _ :: _, h | _ :: _, [], h => by simp [congruentL] at h

mutual
/-- Congruent trees have the same number of leaves. -/
theorem congruent_leaves_length : ∀ (s d : Tup), s.congruent d = true →
    s.leaves.length = d.leaves.length
  | leaf _ _, leaf _ _, _ => rfl
  | tup ss, tup ds, h => by
    simp only [congruent, leaves] at h ⊢
    exact congruentL_leaves_length ss ds h
  | leaf _ _, tup _, h | tup _, leaf _ _, h => by simp [congruent] at h
/-- Congruent lists of trees have the same number of leaves. -/
theorem congruentL_leaves_length : ∀ (ss ds : List Tup), congruentL ss ds = true →
    (leavesL ss).length = (leavesL ds).length
  | [], [], _ => rfl
  | s :: ss, d :: ds, h => by
    simp only [congruentL, Bool.and_eq_true] at h
    simp [leavesL, congruent_leaves_length s d h.1, congruentL_leaves_length ss ds h.2]
  | [], _ :: _, h | _ :: _, [], h => by simp [congruentL] at h
end

/-! ## The scalar coordinate -/

mutual
/-- `crd2idx` of a scalar `v` below the size of shape `s`, with a stride `d` congruent to `s`,
is the dot product of `v`'s colexicographic digits against `s`'s leaves with `d`'s leaves. -/
theorem crd2idx_leaf : ∀ (s d : Tup) (v : Nat) (b : Bool), s.congruent d = true → v < s.size →
    crd2idx (leaf v b) s d = (List.zipWith (· * ·) (colex v s.leaves) d.leaves).sum
  | leaf s _, leaf e _, v, b, _, hv => by
    simp only [size, leaves, List.prod_cons, List.prod_nil, Nat.mul_one] at hv
    simp [crd2idx, len, value, leaves, colex, Nat.mod_eq_of_lt hv]
  | tup ss, tup ds, v, b, h, hv => by
    simp only [congruent] at h
    simp only [crd2idx, congruentL_length ss ds h, ↓reduceIte, len, Nat.lt_irrefl, scalar,
      leaves]
    exact splitIdx_eq ss ds v h hv
  | leaf _ _, tup _, _, _, h, _ | tup _, leaf _ _, _, _, h, _ => by simp [congruent] at h
/-- `splitIdx` of a scalar `v` below the product of the modes' sizes, over modes `ss` and
strides `ds` that are congruent, is the dot product of `v`'s colexicographic digits against the
modes' leaves with the strides' leaves. -/
theorem splitIdx_eq : ∀ (ss ds : List Tup) (v : Nat), congruentL ss ds = true →
    v < (leavesL ss).prod →
    splitIdx v ss ds = (List.zipWith (· * ·) (colex v (leavesL ss)) (leavesL ds)).sum
  | [], [], v, _, _ => by simp [splitIdx, leavesL, colex]
  | [s], [d], v, h, hv => by
    simp only [congruentL, Bool.and_eq_true, and_true] at h
    simp only [leavesL, List.append_nil] at hv ⊢
    exact crd2idx_leaf s d v false h hv
  | s :: s' :: ss, d :: ds, v, h, hv => by
    simp only [congruentL, Bool.and_eq_true] at h
    have hS : 0 < s.size := by
      rcases Nat.eq_zero_or_pos s.size with h0 | h0
      · simp [leavesL, List.prod_append, size] at hv h0; simp [h0] at hv
      · exact h0
    have hv' : v / s.size < (leavesL (s' :: ss)).prod := by
      rw [Nat.div_lt_iff_lt_mul hS, Nat.mul_comm]
      simpa [leavesL, List.prod_append, size] using hv
    have e1 := crd2idx_leaf s d (v % s.size) false h.1 (Nat.mod_lt _ hS)
    have e2 := splitIdx_eq (s' :: ss) ds (v / s.size) h.2 hv'
    have hl : (colex v s.leaves).length = d.leaves.length := by
      rw [colex_length, congruent_leaves_length s d h.1]
    rw [show leavesL (s :: s' :: ss) = s.leaves ++ leavesL (s' :: ss) from rfl,
      show leavesL (d :: ds) = d.leaves ++ leavesL ds from rfl, colex_append,
      sum_zipWith_append _ _ _ _ hl, ← colex_mod v s.leaves]
    simp only [splitIdx]
    rw [e1, e2]
    rfl
  | [], _ :: _, _, h, _ | _ :: _, [], _, h, _ => by simp [congruentL] at h
  | [_], _ :: _ :: _, _, h, _ => by simp [congruentL] at h
end

/-- **The scalar law** (crd2idx card): on a layout whose shape and stride are congruent, a
scalar coordinate `v` below the size has the offset `Σₖ digitₖ * dₖ`, where the digits are
`v`'s colexicographic digits against the shape's leaves (the first leaf fastest) and the `dₖ`
are the stride's leaves. For every shape, nested or flat, static or runtime. -/
theorem Lay.call_scalar (L : Lay) (h : congruentL L.shape L.stride = true) (v : Nat) (b : Bool)
    (hv : v < L.size) :
    L.call (leaf v b) =
      (List.zipWith (· * ·) (colex v (leavesL L.shape)) (leavesL L.stride)).sum :=
  crd2idx_leaf (tup L.shape) (tup L.stride) v b h hv

/-! ## Flat layouts and exact coordinates -/

/-- A leaf coordinate against a leaf stride has the offset coordinate times stride, whatever the
extent. -/
theorem crd2idx_leaf_leaf (x e : Nat) (b b'' : Bool) (s : Tup) :
    crd2idx (leaf x b) s (leaf e b'') = x * e := by
  cases s <;> simp [crd2idx, len, value]

/-- The hierarchical sum over leaf coordinates, any extents and leaf strides of the same length
is the dot product of the coordinates with the strides. -/
theorem zipIdx_flat (b b'' : Bool) : ∀ (c : List Nat) (ss : List Tup) (d : List Nat),
    c.length = ss.length → ss.length = d.length →
    zipIdx (c.map (leaf · b)) ss (d.map (leaf · b'')) = (List.zipWith (· * ·) c d).sum
  | [], [], [], _, _ => rfl
  | x :: c, s :: ss, e :: d, h1, h2 => by
    simp only [List.length_cons, Nat.add_right_cancel_iff] at h1 h2
    simp only [List.map_cons, zipIdx, crd2idx_leaf_leaf, zipIdx_flat b b'' c ss d h1 h2,
      List.zipWith_cons_cons, List.sum_cons]
  | [], _ :: _, _, h, _ | _ :: _, [], _, h, _ => by simp at h
  | [], [], _ :: _, _, h | _ :: _, _ :: _, [], _, h => by simp at h

/-- **Leaf coordinates** (crd2idx card): `crd2idx` of a tuple of leaf coordinates against a tuple
of extents and a tuple of leaf strides, all of the same length, is the dot product of the
coordinates with the strides, with no bound on the coordinates; the extents do not matter. For
every length, 0 and 1 (which `crd2idx` handles by its scalar branch) included, and every static
flag. -/
theorem crd2idx_flat (b b'' : Bool) (c : List Nat) (ss : List Tup) (d : List Nat)
    (h1 : c.length = ss.length) (h2 : ss.length = d.length) :
    crd2idx (tup (c.map (leaf · b))) (tup ss) (tup (d.map (leaf · b''))) =
      (List.zipWith (· * ·) c d).sum := by
  rcases c with _ | ⟨x, _ | ⟨y, c⟩⟩
  · rcases ss with _ | ⟨s, ss⟩
    · rcases d with _ | ⟨e, d⟩
      · rfl
      · simp at h2
    · simp at h1
  · rcases ss with _ | ⟨s, _ | ⟨s', ss⟩⟩
    · simp at h1
    · rcases d with _ | ⟨e, _ | ⟨e', d⟩⟩
      · simp at h2
      · simp [crd2idx, splitIdx, len, scalar, value, crd2idx_leaf_leaf]
      · simp at h2
    · simp at h1
  · rcases ss with _ | ⟨s, _ | ⟨s', ss⟩⟩
    · simp at h1
    · simp at h1
    · rcases d with _ | ⟨e, _ | ⟨e', d⟩⟩
      · simp at h2
      · simp at h2
      · have h1' : c.length = ss.length := by simpa using h1
        have h2' : ss.length = d.length := by simpa using h2
        have hlt : 1 < c.length + 1 + 1 := by omega
        have hc : c.length + 1 + 1 = ss.length + 1 + 1 := by omega
        have hd : ss.length + 1 + 1 = d.length + 1 + 1 := by omega
        rw [crd2idx]
        simp only [List.map_cons, List.length_cons, List.length_map, len, elems, eq_true hlt,
          eq_true hc, eq_true hd, ↓reduceIte]
        exact zipIdx_flat b b'' (x :: y :: c) (s :: s' :: ss) (e :: e' :: d) h1 h2

/-- `Lay.call` of a tuple of leaf coordinates, one per mode, on a layout whose stride is a tuple
of leaves, is the dot product of the coordinates with the strides, whatever the extents. -/
theorem Lay.call_leaves (L : Lay) (c d : List Nat) (b b'' : Bool)
    (hs : L.stride = d.map (leaf · b'')) (h1 : c.length = L.shape.length)
    (h2 : L.shape.length = d.length) :
    L.call (tup (c.map (leaf · b))) = (List.zipWith (· * ·) c d).sum := by
  have hr : ¬ L.rank < (c.map (leaf · b)).length := by simp [Lay.rank, h1]
  simp only [Lay.call, hr, ↓reduceIte, hs]
  exact crd2idx_flat b b'' c L.shape d h1 h2

/-- **Exact coordinates** (crd2idx card): on a flat layout `Lay.flat ms`, a coordinate with one
leaf per mode has the offset `Σₖ cₖ * dₖ`, with no bound on the coordinates. For every rank. -/
theorem Lay.call_flat (ms : List (Nat × Nat)) (c : List Nat) (b : Bool)
    (h : c.length = ms.length) :
    (Lay.flat ms).call (tup (c.map (leaf · b))) =
      (List.zipWith (· * ·) c (ms.map Prod.snd)).sum :=
  Lay.call_leaves _ c _ b true (by simp [Lay.flat]) (by simp [Lay.flat, h]) (by simp [Lay.flat])

/-- The dot product is additive in the coordinate. -/
theorem sum_zipWith_add : ∀ (c c' d : List Nat), c.length = c'.length →
    (List.zipWith (· * ·) (List.zipWith (· + ·) c c') d).sum =
      (List.zipWith (· * ·) c d).sum + (List.zipWith (· * ·) c' d).sum
  | [], [], _, _ => by simp
  | _ :: _, _ :: _, [], _ => by simp
  | x :: c, x' :: c', e :: d, h => by
    simp only [List.length_cons, Nat.add_right_cancel_iff] at h
    simp only [List.zipWith_cons_cons, List.sum_cons, sum_zipWith_add c c' d h, Nat.add_mul]
    omega
  | [], _ :: _, _, h | _ :: _, [], _, h => by simp at h

/-- **Affinity** (is-affine card): on a flat layout, the offset of the sum of two exact
coordinates is the sum of their offsets; stepping one coordinate by 1 adds that mode's stride.
For every flat layout and all coordinates with one leaf per mode. -/
theorem Lay.call_add (ms : List (Nat × Nat)) (c c' : List Nat) (b : Bool)
    (h : c.length = ms.length) (h' : c'.length = ms.length) :
    (Lay.flat ms).call (tup ((List.zipWith (· + ·) c c').map (leaf · b))) =
      (Lay.flat ms).call (tup (c.map (leaf · b))) +
        (Lay.flat ms).call (tup (c'.map (leaf · b))) := by
  rw [Lay.call_flat _ _ _ h, Lay.call_flat _ _ _ h', Lay.call_flat _ _ _ (by simp [h, h']),
    sum_zipWith_add _ _ _ (h.trans h'.symm)]

/-! ## Cosize -/

/-- The product of positive extents is positive. -/
theorem prod_pos (A : List Nat) (h : ∀ s ∈ A, 0 < s) : 0 < A.prod := by
  induction A with
  | nil => simp
  | cons a A ih =>
    simp only [List.mem_cons, forall_eq_or_imp] at h
    simpa using Nat.mul_pos h.1 (ih h.2)

/-- The digits of the last index `A.prod - 1` are the extents minus one, when every extent is
positive. -/
theorem colex_pred (A : List Nat) (h : ∀ s ∈ A, 0 < s) :
    colex (A.prod - 1) A = A.map (· - 1) := by
  induction A with
  | nil => rfl
  | cons a A ih =>
    simp only [List.mem_cons, forall_eq_or_imp] at h
    have hP := prod_pos A h.2
    have e : a * A.prod - 1 = (a - 1) + a * (A.prod - 1) := by
      rw [Nat.mul_sub_one]
      have := Nat.le_mul_of_pos_right a hP
      omega
    simp only [colex, List.prod_cons, List.map_cons, e, Nat.add_mul_mod_self_left,
      Nat.add_mul_div_left _ _ h.1, Nat.div_eq_of_lt (Nat.sub_lt h.1 Nat.one_pos),
      Nat.mod_eq_of_lt (Nat.sub_lt h.1 Nat.one_pos), Nat.zero_add, ih h.2]

/-- **Cosize** (cosize card): on a layout whose shape and stride are congruent and whose extents
are all positive, `cosize` is `1 + Σₖ (sₖ - 1) * dₖ` over the leaves, the formula of Mojo's static
cosize (`_StaticCosize`, layout.mojo:796). For every such shape, nested or flat. -/
theorem Lay.cosize_eq (L : Lay) (h : congruentL L.shape L.stride = true)
    (hpos : ∀ s ∈ leavesL L.shape, 0 < s) :
    L.cosize = (List.zipWith (fun s d => (s - 1) * d) (leavesL L.shape) (leavesL L.stride)).sum
      + 1 := by
  have hS : 0 < L.size := prod_pos _ hpos
  rw [Lay.cosize, Lay.call_scalar L h _ false (Nat.sub_lt hS Nat.one_pos)]
  simp only [Lay.size, Tup.size, Tup.leaves]
  rw [colex_pred _ hpos, List.zipWith_map_left]

/-- Each digit is at most its extent minus one, so the dot product of any digits is at most the
dot product of the extents minus one. -/
theorem sum_colex_le : ∀ (A D : List Nat) (i : Nat), (∀ s ∈ A, 0 < s) →
    (List.zipWith (· * ·) (colex i A) D).sum ≤ (List.zipWith (fun s d => (s - 1) * d) A D).sum
  | [], _, _, _ => by simp [colex]
  | _ :: _, [], _, _ => by simp [colex]
  | a :: A, e :: D, i, h => by
    simp only [List.mem_cons, forall_eq_or_imp] at h
    simp only [colex, List.zipWith_cons_cons, List.sum_cons]
    have h1 : i % a * e ≤ (a - 1) * e :=
      Nat.mul_le_mul_right _ (Nat.le_sub_one_of_lt (Nat.mod_lt _ h.1))
    have h2 := sum_colex_le A D (i / a) h.2
    omega

/-- **The image lies below the cosize** (cosize card): on a layout whose shape and stride are
congruent and whose extents are positive, every scalar coordinate below the size has an offset
below `cosize`; the last one, `size - 1`, has the offset `cosize - 1` by definition. For every
such shape. -/
theorem Lay.call_lt_cosize (L : Lay) (h : congruentL L.shape L.stride = true)
    (hpos : ∀ s ∈ leavesL L.shape, 0 < s) (v : Nat) (b : Bool) (hv : v < L.size) :
    L.call (leaf v b) < L.cosize := by
  rw [Lay.call_scalar L h v b hv, Lay.cosize_eq L h hpos]
  exact Nat.lt_succ_of_le (sum_colex_le _ _ _ hpos)

/-! ## idx2crd -/

/-- idx2crd on a flat layout gives the leaves `(x / d) % s`, mode by mode (a static extent 1,
which idx2crd answers with the static 0, included). -/
theorem idx2crd_flat (x : Nat) (ms : List (Nat × Nat)) :
    (idx2crd x (tup (Lay.flat ms).shape) (tup (Lay.flat ms).stride)).leaves =
      ms.map fun m => x / m.2 % m.1 := by
  simp only [Lay.flat, idx2crd, Tup.leaves]
  induction ms with
  | nil => rfl
  | cons m ms ih =>
    simp only [List.map_cons, idx2crdL, leavesL, ih, idx2crd, value]
    by_cases h1 : m.1 = 1 <;> simp [h1, Tup.leaves, Nat.mod_one]

/-- Adding a part below `g` to a multiple of `g` does not change the quotient by a multiple of
`g`. -/
theorem add_div_of_lt_dvd (a b e g : Nat) (ha : a < g) (hb : g ∣ b) (he : g ∣ e) :
    (a + b) / e = b / e := by
  obtain ⟨m, rfl⟩ := hb
  obtain ⟨n, rfl⟩ := he
  have hg : 0 < g := Nat.lt_of_le_of_lt (Nat.zero_le _) ha
  rw [← Nat.div_div_eq_div_mul, ← Nat.div_div_eq_div_mul, Nat.add_mul_div_left _ _ hg,
    Nat.div_eq_of_lt ha, Nat.zero_add, Nat.mul_div_cancel_left _ hg]

/-- A common divisor of the strides divides every dot product with them. -/
theorem dvd_sum_zipWith (g : Nat) : ∀ (c : List Nat) (ms : List (Nat × Nat)),
    (∀ m ∈ ms, g ∣ m.2) → g ∣ (List.zipWith (· * ·) c (ms.map Prod.snd)).sum
  | [], _, _ => by simp
  | _ :: _, [], _ => by simp
  | x :: c, m :: ms, h => by
    simp only [List.mem_cons, forall_eq_or_imp] at h
    simp only [List.map_cons, List.zipWith_cons_cons, List.sum_cons]
    exact Nat.dvd_add (Nat.dvd_mul_left_of_dvd h.1 x) (dvd_sum_zipWith g c ms h.2)

/-- The digit recovery behind `idx2crd_call`, with an extra multiple `M` of every mode's span. -/
theorem digits_of_nested : ∀ (ms : List (Nat × Nat)) (c : List Nat) (M : Nat),
    ms.Pairwise (fun a b => a.1 * a.2 ∣ b.2) → (∀ m ∈ ms, 0 < m.2) → c.length = ms.length →
    (∀ p ∈ c.zip ms, p.1 < p.2.1) → (∀ m ∈ ms, m.1 * m.2 ∣ M) →
    ms.map (fun m => ((List.zipWith (· * ·) c (ms.map Prod.snd)).sum + M) / m.2 % m.1) = c
  | [], [], _, _, _, _, _, _ => rfl
  | (s, d) :: ms, x :: c, M, hp, hd, hl, hc, hM => by
    simp only [List.pairwise_cons] at hp
    simp only [List.mem_cons, forall_eq_or_imp] at hd hM
    simp only [List.zip_cons_cons, List.mem_cons, forall_eq_or_imp] at hc
    simp only [List.length_cons, Nat.add_right_cancel_iff] at hl
    have hT : s * d ∣ (List.zipWith (· * ·) c (ms.map Prod.snd)).sum + M :=
      Nat.dvd_add (dvd_sum_zipWith _ c ms hp.1) hM.1
    simp only [List.map_cons, List.zipWith_cons_cons, List.sum_cons, List.cons.injEq]
    constructor
    · obtain ⟨q, hq⟩ := hT
      rw [Nat.add_assoc, hq, show x * d + s * d * q = d * (x + s * q) by
        rw [Nat.mul_comm x d, Nat.mul_assoc, Nat.mul_left_comm s d q, ← Nat.mul_add],
        Nat.mul_div_cancel_left _ hd.1, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt hc.1]
    · have hx : x * d < s * d := Nat.mul_lt_mul_of_pos_right hc.1 hd.1
      have e : ∀ m ∈ ms, (x * d + (List.zipWith (· * ·) c (ms.map Prod.snd)).sum + M) / m.2 =
          ((List.zipWith (· * ·) c (ms.map Prod.snd)).sum + M) / m.2 := fun m hm => by
        rw [Nat.add_assoc]
        exact add_div_of_lt_dvd _ _ _ _ hx hT (hp.1 m hm)
      rw [List.map_congr_left (fun m hm => by rw [e m hm])]
      exact digits_of_nested ms c M hp.2 hd.2 hl hc.2 hM.2
  | [], _ :: _, _, _, _, hl, _, _ | _ :: _, [], _, _, _, hl, _, _ => by simp at hl

/-- **idx2crd inverts the coordinate map** (idx2crd card): on a flat layout whose strides are
positive and whose modes are nested in order (each mode's extent times stride divides every
later mode's stride: column-major layouts, padded or not), idx2crd of the offset of an in-bounds
exact coordinate (one leaf per mode, each below its extent) is that coordinate. For every such
layout. -/
theorem idx2crd_call (ms : List (Nat × Nat)) (hp : ms.Pairwise (fun a b => a.1 * a.2 ∣ b.2))
    (hd : ∀ m ∈ ms, 0 < m.2) (c : List Nat) (hl : c.length = ms.length)
    (hc : ∀ p ∈ c.zip ms, p.1 < p.2.1) (b : Bool) :
    (idx2crd ((Lay.flat ms).call (tup (c.map (leaf · b)))) (tup (Lay.flat ms).shape)
      (tup (Lay.flat ms).stride)).leaves = c := by
  rw [Lay.call_flat _ _ _ hl, idx2crd_flat]
  simpa using digits_of_nested ms c 0 hp hd hl hc (fun _ _ => Nat.dvd_zero _)

/-- **idx2crd inverts the coordinate map, reverse order** (idx2crd card): the conclusion of
`idx2crd_call` for a flat layout whose modes are nested in reverse order (each mode's extent
times stride divides every earlier mode's stride: row-major layouts, padded or not). For every
such layout. -/
theorem idx2crd_call_reverse (ms : List (Nat × Nat))
    (hp : ms.reverse.Pairwise (fun a b => a.1 * a.2 ∣ b.2)) (hd : ∀ m ∈ ms, 0 < m.2)
    (c : List Nat) (hl : c.length = ms.length) (hc : ∀ p ∈ c.zip ms, p.1 < p.2.1) (b : Bool) :
    (idx2crd ((Lay.flat ms).call (tup (c.map (leaf · b)))) (tup (Lay.flat ms).shape)
      (tup (Lay.flat ms).stride)).leaves = c := by
  have hz : c.reverse.zip ms.reverse = (c.zip ms).reverse := by
    rw [List.zip_eq_zipWith, List.zip_eq_zipWith, List.reverse_zipWith hl]
  have key := digits_of_nested ms.reverse c.reverse 0 hp (by simpa using hd) (by simp [hl])
    (by rw [hz]; intro p hp; exact hc p (List.mem_reverse.mp hp)) (fun _ _ => Nat.dvd_zero _)
  have hs : (List.zipWith (· * ·) c.reverse (ms.reverse.map Prod.snd)).sum =
      (List.zipWith (· * ·) c (ms.map Prod.snd)).sum := by
    rw [List.map_reverse, ← List.reverse_zipWith (by simp [hl]), List.sum_reverse_nat]
  rw [hs, Nat.add_zero, List.map_reverse] at key
  rw [Lay.call_flat _ _ _ hl, idx2crd_flat]
  simpa using congrArg List.reverse key

/-! ## Reverse -/

/-- **Reversal is an involution** (reverse-transpose card). For every layout. -/
theorem Lay.reverse_reverse (L : Lay) : L.reverse.reverse = L := by
  simp [Lay.reverse]

/-- The product of the leaves of reversed modes is the product of the leaves of the modes. -/
theorem prod_leavesL_reverse : ∀ (ts : List Tup), (leavesL ts.reverse).prod = (leavesL ts).prod
  | [] => rfl
  | t :: ts => by
    have e : ∀ us vs : List Tup, leavesL (us ++ vs) = leavesL us ++ leavesL vs := by
      intro us vs
      induction us with
      | nil => rfl
      | cons u us ih => simp [leavesL, ih]
    rw [List.reverse_cons, e, List.prod_append, prod_leavesL_reverse ts]
    simp [leavesL, List.prod_append, Nat.mul_comm]

/-- **Reversal keeps the size** (reverse-transpose card). For every layout. -/
theorem Lay.size_reverse (L : Lay) : L.reverse.size = L.size := by
  simp only [Lay.size, Lay.reverse, Tup.size, Tup.leaves]
  exact prod_leavesL_reverse L.shape

/-- `zipIdx` over appended lists is the sum over the parts when the first parts have equal
lengths. -/
theorem zipIdx_append : ∀ (a a' b b' e e' : List Tup), a.length = b.length →
    b.length = e.length → zipIdx (a ++ a') (b ++ b') (e ++ e') = zipIdx a b e + zipIdx a' b' e'
  | [], _, [], _, [], _, _, _ => (Nat.zero_add _).symm
  | x :: a, a', y :: b, b', z :: e, e', h1, h2 => by
    simp only [List.length_cons, Nat.add_right_cancel_iff] at h1 h2
    simp only [List.cons_append, zipIdx, zipIdx_append a a' b b' e e' h1 h2, Nat.add_assoc]
  | [], _, _ :: _, _, _, _, h, _ | _ :: _, _, [], _, _, _, h, _ => by simp at h
  | [], _, [], _, _ :: _, _, _, h | _ :: _, _, _ :: _, _, [], _, _, h => by simp at h

/-- `zipIdx` of the reversed lists is `zipIdx` of the lists, for lists of equal lengths. -/
theorem zipIdx_reverse : ∀ (cs ss ds : List Tup), cs.length = ss.length →
    ss.length = ds.length → zipIdx cs.reverse ss.reverse ds.reverse = zipIdx cs ss ds
  | [], [], [], _, _ => rfl
  | c :: cs, s :: ss, d :: ds, h1, h2 => by
    simp only [List.length_cons, Nat.add_right_cancel_iff] at h1 h2
    rw [List.reverse_cons, List.reverse_cons, List.reverse_cons,
      zipIdx_append _ _ _ _ _ _ (by simp [h1]) (by simp [h2]), zipIdx_reverse cs ss ds h1 h2]
    show zipIdx cs ss ds + (crd2idx c s d + 0) = crd2idx c s d + zipIdx cs ss ds
    omega
  | [], _ :: _, _, h, _ | _ :: _, [], _, h, _ => by simp at h
  | [], [], _ :: _, _, h | _ :: _, _ :: _, [], _, h => by simp at h

/-- **Reversal reverses the coordinate** (reverse-transpose card): on a layout whose shape and
stride have equal lengths, the reversed layout maps the reversed coordinate to the same offset,
for a coordinate with one element per mode and a rank of at least 2 (rank 1 is its own
reverse). For every such layout, nested modes included; transpose is reverse. -/
theorem Lay.call_reverse (L : Lay) (cs : List Tup) (hs : L.shape.length = L.stride.length)
    (hc : cs.length = L.rank) (h2 : 2 ≤ cs.length) :
    L.reverse.call (tup cs.reverse) = L.call (tup cs) := by
  -- a coordinate with one element per mode, at least two, takes the hierarchical branch
  have hier : ∀ (M : Lay) (ds : List Tup), M.shape.length = M.stride.length →
      ds.length = M.shape.length → 2 ≤ ds.length →
      M.call (tup ds) = zipIdx ds M.shape M.stride := fun M ds hs hc h2 => by
    have hn : ¬ M.rank < ds.length := by simp only [Lay.rank]; omega
    have h1 : 1 < (tup ds).len := by simp only [len]; omega
    have h3 : (tup ds).len = M.shape.length := hc
    simp only [Lay.call, hn, ↓reduceIte]
    rw [crd2idx]
    simp only [eq_true hs, eq_true h1, eq_true h3, ↓reduceIte, elems]
  have hc' : cs.length = L.shape.length := hc
  rw [hier L cs hs hc' h2, hier L.reverse cs.reverse (by simp [Lay.reverse, hs])
    (by simp [Lay.reverse, hc']) (by simpa using h2)]
  exact zipIdx_reverse cs L.shape L.stride hc' hs

end MojoProof.Layout
