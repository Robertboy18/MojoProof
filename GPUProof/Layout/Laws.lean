import GPUProof.Layout.Algebra
import GPUProof.Layout.Crd

/-!
# The laws of the layout algebra

The laws of docs/proofs/layout-laws.md about the layouts that GPUProof/Layout/Algebra.lean
builds, for every input that meets each law's premises:

* `rowMajor_call_lt`, `rowMajor_onto` and `rowMajor_inj`: a row-major layout of positive
  extents maps its in-bounds coordinates one to one onto the offsets below its size;
* `Lay.coalesce_call` and `Lay.coalesce_size`: coalescing keeps every scalar coordinate's offset
  and the size;
* `Lay.zippedDivide_call` and `Lay.zippedDivide_size`: the divided layout maps a tile coordinate
  and a tile number to the offset of the matching coordinate of the layout, and keeps the size
  when the tile divides the shape;
* `Lay.blockedProduct_call`: the product's offset is the block's offset plus the block's size
  times the tiler's offset;
* `Lay.upcast_scale` and `Lay.upcast_fuse`: on positive strides that are multiples or divisors
  of the factor, `f` times the upcast offset of a coordinate is the layout's offset of the
  coordinate with each divisor stride's leaf multiplied by `f / stride`; a multiple stride is
  divided by the factor and a divisor stride becomes 1, its extent divided by `f / stride`;
  `Lay.upcast_call` and `Lay.upcast_modes` are the case of multiples only;
* `Lay.call_flat_ofNat`: the offset computed in `w`-bit arithmetic is the offset mod `2 ^ w`;
* `Lay.compose_sum`: composing a layout `A` with a layout `B` whose modes each meet the
  divisibility premise `composeDiv` keeps `B`'s size and gives a scalar coordinate the sum, over
  `B`'s modes, of `A`'s offset of that mode's term (digit times stride);
* `Lay.compose_call`: when those terms' digits against `A`'s extents add without carry
  (`noCarry`, which a single-mode `B` always meets), the composite's offset of a coordinate is
  `A`'s offset of `B`'s offset;
* `Lay.compose_all`: the same at every coordinate of `B` under one premise on `A` and `B`
  alone, `carryFree`: at each extent of `A`, the largest digits of `B`'s modes' terms add up to
  less than the extent, and nothing is left above `A`'s last extent.
-/

namespace GPUProof.Layout

open Tup

/-! ## Flat layouts -/

/-- The leaves of a list of leaves are their values. -/
theorem leavesL_map_leaf {α : Type} (f : α → Nat) (b : Bool) :
    ∀ xs : List α, leavesL (xs.map fun x => leaf (f x) b) = xs.map f
  | [] => rfl
  | x :: xs => by simp [leavesL, leaves, leavesL_map_leaf f b xs]

/-- A flat layout's shape and stride are congruent. -/
theorem Lay.flat_congruent : ∀ ms : List (Nat × Nat),
    congruentL (Lay.flat ms).shape (Lay.flat ms).stride = true
  | [] => rfl
  | m :: ms => by
    have := Lay.flat_congruent ms
    simp only [Lay.flat, List.map_cons, congruentL, congruent, Bool.true_and] at this ⊢
    exact this

/-- A flat layout's size is the product of its extents. -/
theorem Lay.size_flat (ms : List (Nat × Nat)) : (Lay.flat ms).size = (ms.map Prod.fst).prod := by
  simp only [Lay.size, Tup.size, Tup.leaves, Lay.flat]
  rw [leavesL_map_leaf]

/-! ## Row-major layouts -/

/-- The dot product of in-bounds digits with the row-major strides is below the product of the
extents. -/
theorem rowMajor_dot_lt : ∀ (ss c : List Nat), c.length = (rowMajor ss).length →
    (∀ p ∈ c.zip (rowMajor ss), p.1 < p.2.1) →
    (List.zipWith (· * ·) c ((rowMajor ss).map Prod.snd)).sum < ss.prod
  | [], [], _, _ => by simp [rowMajor]
  | s :: ss, x :: c, hl, hc => by
    simp only [rowMajor, List.zip_cons_cons, List.mem_cons, forall_eq_or_imp] at hc
    simp only [rowMajor, List.length_cons, Nat.add_right_cancel_iff] at hl
    have ih := rowMajor_dot_lt ss c hl hc.2
    simp only [rowMajor, List.map_cons, List.zipWith_cons_cons, List.sum_cons, List.prod_cons]
    have h := Nat.mul_le_mul_right ss.prod (Nat.succ_le_of_lt hc.1)
    rw [Nat.succ_mul] at h
    omega
  | [], _ :: _, hl, _ => by simp [rowMajor] at hl
  | _ :: _, [], hl, _ => by simp [rowMajor] at hl

/-- The digits `(i / dₖ) % sₖ` of `i` against a row-major layout, dotted with its strides, give
`i % size`. -/
theorem rowMajor_dot_digits : ∀ (ss : List Nat) (i : Nat),
    (List.zipWith (· * ·) ((rowMajor ss).map fun m => i / m.2 % m.1)
      ((rowMajor ss).map Prod.snd)).sum = i % ss.prod
  | [], i => by simp [rowMajor, Nat.mod_one]
  | s :: ss, i => by
    simp only [rowMajor, List.map_cons, List.zipWith_cons_cons, List.sum_cons, List.prod_cons,
      rowMajor_dot_digits ss i]
    rw [Nat.mul_comm s ss.prod, Nat.mod_mul, Nat.mul_comm (i / ss.prod % s) ss.prod,
      Nat.add_comm]

/-- **A row-major layout is bounded by its size** (row-major-views card): every in-bounds
coordinate (one leaf per mode, each below its extent) of a row-major layout has an offset below
the size. For every list of extents. -/
theorem rowMajor_call_lt (ss c : List Nat) (b : Bool) (hl : c.length = (rowMajor ss).length)
    (hc : ∀ p ∈ c.zip (rowMajor ss), p.1 < p.2.1) :
    (Lay.flat (rowMajor ss)).call (tup (c.map (leaf · b))) < ss.prod := by
  rw [Lay.call_flat _ _ _ hl]
  exact rowMajor_dot_lt ss c hl hc

/-- The pairs of a list mapped by `f` with the list itself pair `f a` with `a`. -/
theorem mem_zip_map_self {α β : Type} (f : α → β) :
    ∀ (ms : List α) (p : β × α), p ∈ (ms.map f).zip ms → p.1 = f p.2
  | [], _, h => by simp at h
  | m :: ms, p, h => by
    simp only [List.map_cons, List.zip_cons_cons, List.mem_cons] at h
    rcases h with rfl | h
    · rfl
    · exact mem_zip_map_self f ms p h

/-- **A row-major layout is onto its interval** (row-major-views card): on a row-major layout of
positive extents, every offset `i` below the size is the offset of an in-bounds coordinate, the
one that idx2crd gives (`idx2crd_flat`). For every list of positive extents. -/
theorem rowMajor_onto (ss : List Nat) (hpos : ∀ s ∈ ss, 0 < s) (i : Nat) (hi : i < ss.prod)
    (b : Bool) : ∃ c : List Nat, c.length = (rowMajor ss).length ∧
      (∀ p ∈ c.zip (rowMajor ss), p.1 < p.2.1) ∧
      (Lay.flat (rowMajor ss)).call (tup (c.map (leaf · b))) = i := by
  have hfst : ∀ m ∈ rowMajor ss, 0 < m.1 := by
    clear hi
    induction ss with
    | nil => simp [rowMajor]
    | cons s ss ih =>
      simp only [List.mem_cons, forall_eq_or_imp] at hpos
      simp only [rowMajor, List.mem_cons, forall_eq_or_imp]
      exact ⟨hpos.1, ih hpos.2⟩
  refine ⟨(rowMajor ss).map fun m => i / m.2 % m.1, by simp, fun p hp => ?_, ?_⟩
  · rw [mem_zip_map_self _ _ p hp]
    exact Nat.mod_lt _ (hfst p.2 (List.of_mem_zip hp).2)
  · rw [Lay.call_flat _ _ _ (by simp), rowMajor_dot_digits, Nat.mod_eq_of_lt hi]

/-- Each row-major mode's extent times its stride divides the stride of every earlier mode, the
nesting that `idx2crd_call_reverse` needs. -/
theorem rowMajor_nested : ∀ ss : List Nat,
    (rowMajor ss).reverse.Pairwise (fun a b => a.1 * a.2 ∣ b.2)
  | [] => by simp [rowMajor]
  | s :: ss => by
    have hdvd : ∀ m ∈ rowMajor ss, m.1 * m.2 ∣ ss.prod := by
      clear s
      induction ss with
      | nil => simp [rowMajor]
      | cons t ts ih =>
        simp only [rowMajor, List.mem_cons, forall_eq_or_imp, List.prod_cons]
        exact ⟨Nat.dvd_refl _, fun m hm => Nat.dvd_trans (ih m hm) (Nat.dvd_mul_left _ _)⟩
    rw [List.pairwise_reverse]
    have ih := rowMajor_nested ss
    rw [List.pairwise_reverse] at ih
    simp only [rowMajor, List.pairwise_cons]
    exact ⟨hdvd, ih⟩

/-- The strides of a row-major layout of positive extents are positive. -/
theorem rowMajor_snd_pos : ∀ ss : List Nat, (∀ s ∈ ss, 0 < s) → ∀ m ∈ rowMajor ss, 0 < m.2
  | [], _ => by simp [rowMajor]
  | s :: ss, hpos => by
    simp only [List.mem_cons, forall_eq_or_imp] at hpos
    simp only [rowMajor, List.mem_cons, forall_eq_or_imp]
    exact ⟨prod_pos ss hpos.2, rowMajor_snd_pos ss hpos.2⟩

/-- **A row-major layout is one to one** (row-major-views card): on a row-major layout of
positive extents, two in-bounds coordinates with the same offset are equal. With
`rowMajor_call_lt` and `rowMajor_onto`: the layout is a bijection from its in-bounds coordinates
onto the offsets below its size, so a span over it visits every element once. For every list of
positive extents. -/
theorem rowMajor_inj (ss : List Nat) (hpos : ∀ s ∈ ss, 0 < s) (c c' : List Nat) (b : Bool)
    (hl : c.length = (rowMajor ss).length) (hc : ∀ p ∈ c.zip (rowMajor ss), p.1 < p.2.1)
    (hl' : c'.length = (rowMajor ss).length) (hc' : ∀ p ∈ c'.zip (rowMajor ss), p.1 < p.2.1)
    (h : (Lay.flat (rowMajor ss)).call (tup (c.map (leaf · b))) =
      (Lay.flat (rowMajor ss)).call (tup (c'.map (leaf · b)))) : c = c' := by
  have hd := rowMajor_snd_pos ss hpos
  rw [← idx2crd_call_reverse (rowMajor ss) (rowMajor_nested ss) hd c hl hc b, h,
    idx2crd_call_reverse (rowMajor ss) (rowMajor_nested ss) hd c' hl' hc' b]

/-! ## Coalesce -/

/-- The offset of the scalar `j` in the flat layout of the (extent, stride) pairs `ps`: the dot
product of `j`'s colexicographic digits against the extents with the strides. Below the product
of the extents it is `(Lay.flat ps).call (leaf j b)` (`Lay.call_scalar`). -/
def dotColex (ps : List (Nat × Nat)) (j : Nat) : Nat :=
  (List.zipWith (· * ·) (colex j (ps.map Prod.fst)) (ps.map Prod.snd)).sum

/-- `dotColex` of appended pairs: the first part's offset plus the second part's offset of the
quotient by the first part's size. For every `j`. -/
theorem dotColex_append (A B : List (Nat × Nat)) (j : Nat) :
    dotColex (A ++ B) j = dotColex A j + dotColex B (j / (A.map Prod.fst).prod) := by
  simp only [dotColex, List.map_append, colex_append]
  exact sum_zipWith_append _ _ _ _ (by simp [colex_length])

/-- `dotColex` of 0 is 0. -/
theorem dotColex_zero : ∀ ps : List (Nat × Nat), dotColex ps 0 = 0
  | [] => rfl
  | p :: ps => by
    have := dotColex_zero ps
    simp only [dotColex] at this ⊢
    simp [colex, this]

/-- `dotColex` depends only on the index mod the product of the extents. For every `j`. -/
theorem dotColex_mod (ps : List (Nat × Nat)) (j : Nat) :
    dotColex ps (j % (ps.map Prod.fst).prod) = dotColex ps j := by
  simp only [dotColex, colex_mod]

/-- The modes of a flat layout are its (extent, stride) pairs. -/
theorem Lay.modes_flat (ps : List (Nat × Nat)) : (Lay.flat ps).modes = ps := by
  simp only [Lay.modes, Lay.flat, leavesL_map_leaf]
  induction ps with
  | nil => rfl
  | cons p ps ih => simp [ih]

/-- A coalesce step keeps the product of the extents of the pairs kept so far and the new mode. -/
theorem coalesceStep_prod (acc : List (Nat × Nat)) (m : Nat × Nat) :
    ((coalesceStep acc m).map Prod.fst).prod = ((acc ++ [m]).map Prod.fst).prod := by
  unfold coalesceStep
  by_cases h1 : m.1 = 1
  · simp [h1]
  · rcases List.eq_nil_or_concat acc with rfl | ⟨D, ⟨ps, pd⟩, rfl⟩
    · simp [h1]
    · simp only [h1, ↓reduceIte, List.concat_eq_append, List.getLast?_concat,
        List.dropLast_concat]
      by_cases h2 : ps = 1
      · simp [h2]
      · by_cases h3 : ps * pd = m.2
        · simp [h2, h3, List.prod_append]
        · simp [h2, h3]

/-- A coalesce step keeps the offset of every scalar: the pairs it returns give `j` the offset
that the pairs kept so far followed by the new mode give it. For every `j`. -/
theorem coalesceStep_dot (acc : List (Nat × Nat)) (m : Nat × Nat) (j : Nat) :
    dotColex (coalesceStep acc m) j = dotColex (acc ++ [m]) j := by
  have one : ∀ (x : Nat) (q : Nat × Nat), dotColex [q] x = x % q.1 * q.2 := fun x q => by
    simp [dotColex, colex]
  unfold coalesceStep
  by_cases h1 : m.1 = 1
  · simp only [h1, ↓reduceIte]
    rw [dotColex_append, one, h1, Nat.mod_one, Nat.zero_mul, Nat.add_zero]
  · rcases List.eq_nil_or_concat acc with rfl | ⟨D, ⟨ps, pd⟩, rfl⟩
    · simp [h1]
    · simp only [h1, ↓reduceIte, List.concat_eq_append, List.getLast?_concat,
        List.dropLast_concat]
      by_cases h2 : ps = 1
      · simp only [h2, ↓reduceIte]
        rw [List.append_assoc, dotColex_append, dotColex_append D, dotColex_append [(1, pd)]]
        simp [one, Nat.mod_one]
      · by_cases h3 : ps * pd = m.2
        · simp only [h2, h3, ↓reduceIte]
          rw [List.append_assoc, dotColex_append, dotColex_append D, dotColex_append [(ps, pd)],
            one, one, one, ← h3]
          simp only [List.map_cons, List.map_nil, List.prod_cons, List.prod_nil, Nat.mul_one]
          rw [Nat.mod_mul, Nat.add_mul, Nat.mul_assoc, Nat.mul_comm ps (_ * pd),
            Nat.mul_assoc, Nat.mul_comm pd ps]
        · simp [h2, h3]

/-- Folding coalesce steps keeps the product of the extents and every scalar's offset. -/
theorem coalesce_fold : ∀ (ms acc : List (Nat × Nat)),
    ((ms.foldl coalesceStep acc).map Prod.fst).prod = ((acc ++ ms).map Prod.fst).prod ∧
      ∀ j, dotColex (ms.foldl coalesceStep acc) j = dotColex (acc ++ ms) j
  | [], acc => by simp
  | m :: ms, acc => by
    obtain ⟨hp, hd⟩ := coalesce_fold ms (coalesceStep acc m)
    have e : acc ++ m :: ms = (acc ++ [m]) ++ ms := by simp
    refine ⟨?_, fun j => ?_⟩
    · rw [List.foldl_cons, hp, e, List.map_append, List.map_append, List.prod_append,
        List.prod_append, coalesceStep_prod]
    · rw [List.foldl_cons, hd, e, dotColex_append, dotColex_append, coalesceStep_dot,
        coalesceStep_prod]

/-- On a layout whose shape and stride are congruent, the size is the product of the extents of
the flattened modes, and every scalar below it has the offset `dotColex` of the modes. -/
theorem Lay.modes_size_call (L : Lay) (h : congruentL L.shape L.stride = true) :
    (L.modes.map Prod.fst).prod = L.size ∧
      ∀ v b, v < L.size → L.call (leaf v b) = dotColex L.modes v := by
  have hl := congruentL_leaves_length _ _ h
  have h1 : L.modes.map Prod.fst = leavesL L.shape := List.map_fst_zip (by omega)
  have h2 : L.modes.map Prod.snd = leavesL L.stride := List.map_snd_zip (by omega)
  refine ⟨by rw [h1]; rfl, fun v b hv => ?_⟩
  rw [Lay.call_scalar L h v b hv, dotColex, h1, h2]

/-- **Coalesce keeps the size** (coalesce card): on a layout whose shape and stride are
congruent, the coalesced layout has the same size. For every such layout, nested or flat. -/
theorem Lay.coalesce_size (L : Lay) (h : congruentL L.shape L.stride = true) :
    L.coalesce.size = L.size := by
  rw [Lay.coalesce, Lay.size_flat, (coalesce_fold L.modes [(1, 0)]).1, ← (L.modes_size_call h).1]
  simp

/-- **Coalesce keeps the offsets** (coalesce card): on a layout whose shape and stride are
congruent, the coalesced layout gives every scalar coordinate below the size the same offset as
the layout. For every such layout, nested or flat; coalesce flattens it. -/
theorem Lay.coalesce_call (L : Lay) (h : congruentL L.shape L.stride = true) (v : Nat)
    (b : Bool) (hv : v < L.size) : L.coalesce.call (leaf v b) = L.call (leaf v b) := by
  have hv' : v < L.coalesce.size := by rw [Lay.coalesce_size L h]; exact hv
  rw [(L.modes_size_call h).2 v b hv]
  have := ((Lay.flat (L.modes.foldl coalesceStep [(1, 0)])).modes_size_call
    (Lay.flat_congruent _)).2 v b hv'
  rw [Lay.coalesce, this, Lay.modes_flat, (coalesce_fold L.modes [(1, 0)]).2, dotColex_append]
  simp [dotColex, colex]

/-! ## Zipped divide -/

/-- `crd2idx` of two leaf coordinate tuples, read as one mode each, splits into the two dot
products. -/
theorem sum_zipWith_tile (x y t d : List Nat) (hx : x.length = d.length)
    (hy : y.length = d.length) (ht : t.length = d.length) :
    (List.zipWith (· * ·) x d).sum + (List.zipWith (· * ·) y (List.zipWith (· * ·) d t)).sum =
      (List.zipWith (· * ·) (List.zipWith (· + ·) x (List.zipWith (· * ·) t y)) d).sum := by
  induction d generalizing x y t with
  | nil =>
    rw [List.length_eq_zero_iff.mp hx, List.length_eq_zero_iff.mp hy,
      List.length_eq_zero_iff.mp ht]
    rfl
  | cons e d ih =>
    rcases x with _ | ⟨a, x⟩ <;> rcases y with _ | ⟨c, y⟩ <;> rcases t with _ | ⟨k, t⟩ <;>
      simp only [List.length_cons, List.length_nil] at hx hy ht <;> try omega
    simp only [List.zipWith_cons_cons, List.sum_cons]
    have := ih x y t (by omega) (by omega) (by omega)
    have hm : c * (e * k) = k * c * e := by
      rw [Nat.mul_comm e k, ← Nat.mul_assoc, Nat.mul_comm c k]
    rw [← this, Nat.add_mul, hm]
    omega

/-- **Zipped divide's coordinates** (zipped-divide card): on a flat layout and a tile with one
extent per mode, the divided layout maps the tile coordinate `x` and the tile number `y` (one
leaf per mode each) to the offset of the coordinate `x + t * y` in the layout. For every flat
layout of every rank, every tile and every coordinate, with no bound on the coordinates; no
divisibility is needed. -/
theorem Lay.zippedDivide_call (ms : List (Nat × Nat)) (t x y : List Nat) (b : Bool)
    (ht : t.length = ms.length) (hx : x.length = ms.length) (hy : y.length = ms.length) :
    ((Lay.flat ms).zippedDivide t).call (tup [tup (x.map (leaf · b)), tup (y.map (leaf · b))]) =
      (Lay.flat ms).call (tup ((List.zipWith (· + ·) x (List.zipWith (· * ·) t y)).map
        (leaf · b))) := by
  have hcall : ((Lay.flat ms).zippedDivide t).call
      (tup [tup (x.map (leaf · b)), tup (y.map (leaf · b))]) =
      crd2idx (tup (x.map (leaf · b))) (tup (t.map (leaf · true))) (tup (Lay.flat ms).stride) +
        (crd2idx (tup (y.map (leaf · b)))
          (tup (List.zipWith (fun s k => leaf (s.value / k) true) (Lay.flat ms).shape t))
          (tup (List.zipWith (fun d k => leaf (d.value * k) true) (Lay.flat ms).stride t)) + 0) :=
    rfl
  have hs : (Lay.flat ms).stride = (ms.map Prod.snd).map (leaf · true) := by simp [Lay.flat]
  have hm : List.zipWith (fun d k => leaf (d.value * k) true) (Lay.flat ms).stride t =
      (List.zipWith (· * ·) (ms.map Prod.snd) t).map (leaf · true) := by
    simp [Lay.flat, List.zipWith_map_left, List.map_zipWith, value]
  rw [hcall, hm, hs, crd2idx_flat b true x _ _ (by simp [hx, ht]) (by simp [ht]),
    crd2idx_flat b true y _ _ (by simp [Lay.flat, hy, ht]) (by simp [Lay.flat, ht]),
    Nat.add_zero, Lay.call_flat _ _ _ (by simp [hx, hy, ht])]
  exact sum_zipWith_tile x y t _ (by simp [hx]) (by simp [hy]) (by simp [ht])

/-- The leaves of a list of leaves made pairwise from two lists are the pairwise values. -/
theorem leavesL_zipWith_leaf {α β : Type} (f : α → β → Nat) (b : Bool) :
    ∀ (xs : List α) (ys : List β),
      leavesL (List.zipWith (fun x y => leaf (f x y) b) xs ys) = List.zipWith f xs ys
  | [], _ => rfl
  | _ :: _, [] => rfl
  | x :: xs, y :: ys => by simp [leavesL, leaves, leavesL_zipWith_leaf f b xs ys]

/-- When each tile extent divides its extent, the tile's product times the product of the
quotients is the product of the extents. -/
theorem prod_mul_prod_div : ∀ (ms : List (Nat × Nat)) (t : List Nat), t.length = ms.length →
    (∀ p ∈ ms.zip t, p.2 ∣ p.1.1) →
    t.prod * (List.zipWith (fun m k => m.1 / k) ms t).prod = (ms.map Prod.fst).prod
  | [], [], _, _ => rfl
  | m :: ms, k :: t, hl, hd => by
    simp only [List.zip_cons_cons, List.mem_cons, forall_eq_or_imp] at hd
    have ih := prod_mul_prod_div ms t (by simpa using hl) hd.2
    simp only [List.prod_cons, List.zipWith_cons_cons, List.map_cons]
    rw [← ih, Nat.mul_mul_mul_comm, Nat.mul_div_cancel' hd.1]
  | [], _ :: _, hl, _ | _ :: _, [], hl, _ => by simp at hl

/-- **Zipped divide keeps the size when the tile divides** (zipped-divide card): on a flat layout
and a tile with one positive extent per mode, each dividing the mode's extent, the divided layout
has the layout's size. For every such layout and tile, nested results included. -/
theorem Lay.zippedDivide_size (ms : List (Nat × Nat)) (t : List Nat) (ht : t.length = ms.length)
    (hdvd : ∀ p ∈ ms.zip t, p.2 ∣ p.1.1) :
    ((Lay.flat ms).zippedDivide t).size = (Lay.flat ms).size := by
  have e1 : leavesL (t.map (leaf · true)) = t := by
    simpa using leavesL_map_leaf (fun x => x) true t
  have e2 : leavesL (List.zipWith (fun s k => leaf (s.value / k) true) (Lay.flat ms).shape t) =
      List.zipWith (fun m k => m.1 / k) ms t := by
    simp only [Lay.flat, List.zipWith_map_left, value]
    exact leavesL_zipWith_leaf _ true ms t
  rw [Lay.size_flat]
  simp only [Lay.size, Tup.size, Tup.leaves, Lay.zippedDivide, leavesL, e1, e2, List.append_nil,
    List.prod_append]
  exact prod_mul_prod_div ms t ht hdvd

/-! ## Blocked product -/

/-- The hierarchical offset of pairs `(xᵢ, yᵢ)` in the modes `((mᵢ.1, nᵢ.1) : (mᵢ.2, S * nᵢ.2))`
is the dot product of `x` with the `mᵢ.2` plus `S` times the dot product of `y` with the
`nᵢ.2`. -/
theorem zipIdx_pairs (b : Bool) (S : Nat) : ∀ (x y : List Nat) (ms ns : List (Nat × Nat)),
    x.length = ms.length → y.length = ms.length → ns.length = ms.length →
    zipIdx (List.zipWith (fun a c => tup [leaf a b, leaf c b]) x y)
        (List.zipWith (fun m n => tup [leaf m.1 true, leaf n.1 true]) ms ns)
        (List.zipWith (fun m n => tup [leaf m.2 true, leaf (S * n.2) true]) ms ns) =
      (List.zipWith (· * ·) x (ms.map Prod.snd)).sum +
        S * (List.zipWith (· * ·) y (ns.map Prod.snd)).sum
  | x, y, [], ns, hx, hy, hn => by
    simp only [List.length_nil, List.length_eq_zero_iff] at hx hy hn
    subst hx hy hn
    simp [zipIdx]
  | x, y, m :: ms, ns, hx, hy, hn => by
    rcases x with _ | ⟨a, x⟩ <;> rcases y with _ | ⟨c, y⟩ <;> rcases ns with _ | ⟨n, ns⟩ <;>
      simp only [List.length_cons, List.length_nil] at hx hy hn <;> try omega
    simp only [List.zipWith_cons_cons, zipIdx, List.map_cons, List.sum_cons,
      zipIdx_pairs b S x y ms ns (by omega) (by omega) (by omega)]
    have e := crd2idx_flat b true [a, c] [leaf m.1 true, leaf n.1 true] [m.2, S * n.2] rfl rfl
    simp only [List.map_cons, List.map_nil, List.zipWith_cons_cons, List.zipWith_nil_left,
      List.sum_cons, List.sum_nil, Nat.add_zero] at e
    rw [e, Nat.mul_add]
    have : c * (S * n.2) = S * (c * n.2) := Nat.mul_left_comm c S n.2
    omega

/-- **Blocked product's coordinates** (blocked-product card): for a flat block and a flat tiler
of the same rank, at least 2, the product maps the coordinate whose mode `i` is `(xᵢ, yᵢ)` to the
block's offset of `x` plus the block's size times the tiler's offset of `y`. This is the code;
the docstring's `block.cosize` agrees with it exactly when the block's cosize is its size. For
every such block, tiler and coordinate. -/
theorem Lay.blockedProduct_call (ms ns : List (Nat × Nat)) (x y : List Nat) (b : Bool)
    (h2 : 2 ≤ ms.length) (hn : ns.length = ms.length) (hx : x.length = ms.length)
    (hy : y.length = ms.length) :
    (Lay.blockedProduct (Lay.flat ms) (Lay.flat ns)).call
        (tup (List.zipWith (fun a c => tup [leaf a b, leaf c b]) x y)) =
      (Lay.flat ms).call (tup (x.map (leaf · b))) +
        (Lay.flat ms).size * (Lay.flat ns).call (tup (y.map (leaf · b))) := by
  have fs : ∀ ps : List (Nat × Nat), (Lay.flat ps).shape = ps.map fun p => leaf p.1 true :=
    fun _ => rfl
  have fd : ∀ ps : List (Nat × Nat), (Lay.flat ps).stride = ps.map fun p => leaf p.2 true :=
    fun _ => rfl
  have hs : (Lay.blockedProduct (Lay.flat ms) (Lay.flat ns)).shape =
      List.zipWith (fun m n => tup [leaf m.1 true, leaf n.1 true]) ms ns := by
    simp only [Lay.blockedProduct, fs, List.zipWith_map_left, List.zipWith_map_right]
  have hd : (Lay.blockedProduct (Lay.flat ms) (Lay.flat ns)).stride = List.zipWith
      (fun m n => tup [leaf m.2 true, leaf ((Lay.flat ms).size * n.2) true]) ms ns := by
    simp only [Lay.blockedProduct, fd, List.zipWith_map_left, List.zipWith_map_right, value]
  -- the coordinate has one element per mode, at least two: the hierarchical branch
  have hl : (List.zipWith (fun a c => tup [leaf a b, leaf c b]) x y).length = ms.length := by
    simp [hx, hy]
  have hn' : ¬ (Lay.blockedProduct (Lay.flat ms) (Lay.flat ns)).rank <
      (List.zipWith (fun a c => tup [leaf a b, leaf c b]) x y).length := by
    simp [Lay.rank, hs, hl, hn]
  have h1 : 1 < (tup (List.zipWith (fun a c => tup [leaf a b, leaf c b]) x y)).len := by
    simp only [len, hl]; omega
  have h3 : (tup (List.zipWith (fun a c => tup [leaf a b, leaf c b]) x y)).len =
      (Lay.blockedProduct (Lay.flat ms) (Lay.flat ns)).shape.length := by
    simp [len, hl, hs, hn]
  have h4 : (Lay.blockedProduct (Lay.flat ms) (Lay.flat ns)).shape.length =
      (Lay.blockedProduct (Lay.flat ms) (Lay.flat ns)).stride.length := by
    simp [hs, hd]
  rw [Lay.call_flat _ _ _ hx, Lay.call_flat _ _ _ (hy.trans hn.symm)]
  simp only [Lay.call, hn', ↓reduceIte]
  rw [crd2idx]
  simp only [eq_true h4, eq_true h1, eq_true h3, ↓reduceIte, elems]
  rw [hs, hd]
  exact zipIdx_pairs b _ x y ms ns hx hy hn

/-! ## Upcast -/

/-- For a positive `d` that the factor `f` divides, `shape_div(f, d)` is 1 and `shape_div(d, f)` is
`d / f`: the two divisions upcast makes on a mode of stride `d`. -/
theorem shapeDiv_factor (f d : Nat) (h0 : 0 < d) (hf : f ∣ d) :
    shapeDiv f d = 1 ∧ shapeDiv d f = d / f := by
  have hf0 : 0 < f := Nat.pos_of_ne_zero fun h => by
    subst h; exact absurd (Nat.eq_zero_of_zero_dvd hf) (Nat.pos_iff_ne_zero.mp h0)
  have hle : f ≤ d := Nat.le_of_dvd h0 hf
  refine ⟨?_, by simp [shapeDiv, Nat.mod_eq_zero_of_dvd hf]⟩
  unfold shapeDiv
  by_cases h : f % d = 0
  · have hfd : f = d := Nat.le_antisymm hle (Nat.le_of_dvd hf0 (Nat.dvd_of_mod_eq_zero h))
    subst hfd
    simp [Nat.div_self h0]
  · simp [h, Nat.pos_iff_ne_zero.mp h0]

/-- For a positive `d` that divides a positive factor `f`, `shape_div(f, d)` is `f / d` and
`shape_div(d, f)` is 1: the two divisions upcast makes on a mode of stride `d`. -/
theorem shapeDiv_dvd (f d : Nat) (h0 : 0 < d) (hf : 0 < f) (hd : d ∣ f) :
    shapeDiv f d = f / d ∧ shapeDiv d f = 1 := by
  refine ⟨by simp [shapeDiv, Nat.mod_eq_zero_of_dvd hd], ?_⟩
  have hle : d ≤ f := Nat.le_of_dvd hf hd
  unfold shapeDiv
  by_cases h : d % f = 0
  · have : d = f := Nat.le_antisymm hle (Nat.le_of_dvd h0 (Nat.dvd_of_mod_eq_zero h))
    subst this; simp [Nat.div_self h0]
  · simp [h, Nat.pos_iff_ne_zero.mp hf]

/-- On a positive stride `d` that the factor `f` divides or that divides `f`, `f` times the new
stride `shape_div(d, f)` is `shape_div(f, d)` times `d`. -/
theorem shapeDiv_mul (f d : Nat) (h0 : 0 < d) (h : f ∣ d ∨ d ∣ f) :
    f * shapeDiv d f = shapeDiv f d * d := by
  rcases h with h | h
  · rw [(shapeDiv_factor f d h0 h).1, (shapeDiv_factor f d h0 h).2, Nat.mul_div_cancel' h,
      Nat.one_mul]
  · rcases Nat.eq_zero_or_pos f with rfl | hf
    · simp [shapeDiv]
    · rw [(shapeDiv_dvd f d h0 hf h).1, (shapeDiv_dvd f d h0 hf h).2, Nat.mul_one,
        Nat.div_mul_cancel h]

/-- **Upcast scales the coordinate** (upcast card): on a flat layout whose strides are positive,
each a multiple of the factor `f` or a divisor of it, `f` times the upcast layout's offset of a
coordinate `c` (one leaf per mode) is the layout's offset of `c` with each leaf `cₖ` multiplied
by `shape_div(f, dₖ)`: by 1 on a stride that `f` divides, and by `f / dₖ` on a stride that
divides `f`, whose `f / dₖ` consecutive elements upcast fuses into one. For every such layout,
factor and coordinate, with no bound on the coordinate. -/
theorem Lay.upcast_scale (f : Nat) (ms : List (Nat × Nat))
    (hd : ∀ m ∈ ms, 0 < m.2 ∧ (f ∣ m.2 ∨ m.2 ∣ f)) (c : List Nat) (b : Bool)
    (hc : c.length = ms.length) :
    f * (Lay.upcast f (Lay.flat ms)).call (tup (c.map (leaf · b))) =
      (Lay.flat ms).call
        (tup ((List.zipWith (fun x m => x * shapeDiv f m.2) c ms).map (leaf · b))) := by
  rw [Lay.call_leaves _ c (ms.map fun m => shapeDiv m.2 f) b true
      (by simp [Lay.upcast, Lay.flat, value]) (by simp [Lay.upcast, Lay.flat, hc])
      (by simp [Lay.upcast, Lay.flat]),
    Lay.call_flat _ _ _ (by simp [hc])]
  clear hc
  induction ms generalizing c with
  | nil => simp
  | cons m ms ih =>
    rcases c with _ | ⟨x, c⟩
    · simp
    · simp only [List.mem_cons, forall_eq_or_imp] at hd
      simp only [List.map_cons, List.zipWith_cons_cons, List.sum_cons, Nat.mul_add]
      rw [ih hd.2 c, Nat.mul_left_comm, shapeDiv_mul f m.2 hd.1.1 hd.1.2, ← Nat.mul_assoc]

/-- **Upcast divides the offsets** (upcast card): on a flat layout whose strides are positive
multiples of the factor `f`, `f` times the upcast layout's offset of a coordinate (one leaf per
mode) is the layout's offset of it: `Lay.upcast_scale`, where every leaf is multiplied by 1. For
every such layout, factor and coordinate. -/
theorem Lay.upcast_call (f : Nat) (ms : List (Nat × Nat)) (hd : ∀ m ∈ ms, 0 < m.2 ∧ f ∣ m.2)
    (c : List Nat) (b : Bool) (hc : c.length = ms.length) :
    f * (Lay.upcast f (Lay.flat ms)).call (tup (c.map (leaf · b))) =
      (Lay.flat ms).call (tup (c.map (leaf · b))) := by
  have hs : List.zipWith (fun x m => x * shapeDiv f m.2) c ms = c := by
    clear b
    induction ms generalizing c with
    | nil => cases c <;> simp_all
    | cons m ms ih =>
      cases c with
      | nil => simp
      | cons x c =>
        simp only [List.mem_cons, forall_eq_or_imp] at hd
        simp [(shapeDiv_factor f m.2 hd.1.1 hd.1.2).1, ih hd.2 c (by simpa using hc)]
  rw [Lay.upcast_scale f ms (fun m h => ⟨(hd m h).1, Or.inl (hd m h).2⟩) c b hc, hs]

/-- **Upcast's modes** (upcast card): on a flat layout whose strides are positive, each a
multiple of the factor `f`, or a divisor `dₖ` of a positive `f` with `f / dₖ` dividing the
extent, upcast keeps the extent and divides the stride by `f` on a multiple of `f`, and divides
the extent by `f / dₖ` and makes the stride 1 on a divisor of `f`. For every such layout and
factor; Mojo's docstring example `upcast[2](row_major[4, 8])`, (4, 4):(4, 1), is an instance. -/
theorem Lay.upcast_fuse (f : Nat) : ∀ ms : List (Nat × Nat),
    (∀ m ∈ ms, 0 < m.2 ∧ (f ∣ m.2 ∨ 0 < f ∧ m.2 ∣ f ∧ f / m.2 ∣ m.1)) →
    (Lay.upcast f (Lay.flat ms)).modes =
      ms.map fun m => if f ∣ m.2 then (m.1, m.2 / f) else (m.1 / (f / m.2), 1)
  | [], _ => rfl
  | m :: ms, hd => by
    simp only [List.mem_cons, forall_eq_or_imp] at hd
    have ih := Lay.upcast_fuse f ms hd.2
    have hm : (shapeDiv m.1 (shapeDiv f m.2), shapeDiv m.2 f) =
        if f ∣ m.2 then (m.1, m.2 / f) else (m.1 / (f / m.2), 1) := by
      by_cases h : f ∣ m.2
      · obtain ⟨e1, e2⟩ := shapeDiv_factor f m.2 hd.1.1 h
        simp only [e1, e2, h, ↓reduceIte]
        simp [shapeDiv, Nat.mod_one]
      · obtain ⟨hf, hdf, hs⟩ := hd.1.2.resolve_left h
        obtain ⟨e1, e2⟩ := shapeDiv_dvd f m.2 hd.1.1 hf hdf
        simp only [e1, e2, h, ↓reduceIte]
        simp [shapeDiv, Nat.mod_eq_zero_of_dvd hs]
    simp only [Lay.upcast, Lay.flat, Lay.modes, List.map_cons, List.zipWith_cons_cons, leavesL,
      leaves, value, List.singleton_append, List.zip_cons_cons] at ih ⊢
    rw [ih, hm]

/-- **Upcast keeps the extents** (upcast card): on a flat layout whose strides are positive
multiples of the factor `f`, the upcast layout's modes are the extents with the strides divided
by `f`: `Lay.upcast_fuse` with every stride a multiple of `f`. For every such layout and
factor. -/
theorem Lay.upcast_modes (f : Nat) (ms : List (Nat × Nat)) (hd : ∀ m ∈ ms, 0 < m.2 ∧ f ∣ m.2) :
    (Lay.upcast f (Lay.flat ms)).modes = ms.map fun m => (m.1, m.2 / f) :=
  (Lay.upcast_fuse f ms fun m h => ⟨(hd m h).1, Or.inl (hd m h).2⟩).trans
    (List.map_congr_left fun m h => by simp only [(hd m h).2, ↓reduceIte])

/-! ## The index width -/

/-- **The index width** (index-width card): on a flat layout, the dot product of a coordinate
(one leaf per mode) with the strides computed in `w`-bit arithmetic, each product and each sum
wrapped, is the offset mod `2 ^ w`. For every width, flat layout and coordinate. -/
theorem Lay.call_flat_ofNat (w : Nat) (ms : List (Nat × Nat)) (c : List Nat) (b : Bool)
    (h : c.length = ms.length) :
    (List.zipWith (fun x d => BitVec.ofNat w x * BitVec.ofNat w d) c (ms.map Prod.snd)).sum =
      BitVec.ofNat w ((Lay.flat ms).call (tup (c.map (leaf · b)))) := by
  rw [Lay.call_flat _ _ _ h]
  clear h
  induction c generalizing ms with
  | nil => simp
  | cons x c ih =>
    rcases ms with _ | ⟨m, ms⟩
    · simp
    · simp only [List.map_cons, List.zipWith_cons_cons, List.sum_cons, ih ms,
        BitVec.ofNat_add, BitVec.ofNat_mul]

/-- The `w`-bit offset is exact when the offset is below `2 ^ w`. -/
theorem Lay.call_flat_toNat (w : Nat) (ms : List (Nat × Nat)) (c : List Nat) (b : Bool)
    (h : c.length = ms.length) (hw : (Lay.flat ms).call (tup (c.map (leaf · b))) < 2 ^ w) :
    (List.zipWith (fun x d => BitVec.ofNat w x * BitVec.ofNat w d) c (ms.map Prod.snd)).sum.toNat =
      (Lay.flat ms).call (tup (c.map (leaf · b))) := by
  rw [Lay.call_flat_ofNat w ms c b h, BitVec.toNat_ofNat, Nat.mod_eq_of_lt hw]

/-! ## Composition -/

/-- The divisibility premise of composing a single mode (extent `e`, stride `r`) through the
modes `ms` of the outer layout that `_compose_leaf` crosses (all but the last): at each mode
`(a, _)`, either `a` divides the remaining stride `r`, or `r` divides `a` and the remaining
extent `e` is at most `a / r` or a multiple of it; then the same for the next mode, from the
extent and stride `composeStep` leaves. CuTe's stride and shape divisibility conditions imply
it. -/
def composeDiv : List (Nat × Nat) → Nat × Nat → Bool
  | [], _ => true
  | (a, ad) :: ms, (e, r) =>
    (r % a == 0 || a % r == 0 && (decide (e ≤ a / r) || e % (a / r) == 0)) &&
      composeDiv ms (composeStep (a, ad) ([], e, r)).2

/-- The steps of `composeLeaf` keep the product of the extents: the extents emitted, times the
extent left, are the extents kept so far times the extent the steps start from. For every list
of modes under `composeDiv`, positive stride and positive extent. -/
theorem composeFold_prod : ∀ (M out : List (Nat × Nat)) (e r : Nat),
    composeDiv M (e, r) = true → 0 < r → 0 < e →
    ((M.foldl (fun st cd => composeStep cd st) (out, e, r)).1.map Prod.fst).prod *
        (M.foldl (fun st cd => composeStep cd st) (out, e, r)).2.1 =
      (out.map Prod.fst).prod * e
  | [], out, e, r, _, _, _ => rfl
  | (a, ad) :: M, out, e, r, hd, hr, he => by
    simp only [composeDiv, Bool.and_eq_true, Bool.or_eq_true, beq_iff_eq,
      decide_eq_true_eq] at hd
    obtain ⟨hc, hd⟩ := hd
    simp only [List.foldl_cons]
    by_cases h1 : r % a = 0
    · obtain ⟨k, rfl⟩ := Nat.dvd_of_mod_eq_zero h1
      have ha : 0 < a := Nat.pos_of_ne_zero (by rintro rfl; simp at hr)
      have hk : 0 < k := Nat.pos_of_ne_zero (by rintro rfl; simp at hr)
      have hns : shapeDiv a (a * k) = 1 := by
        by_cases k1 : k = 1
        · subst k1; simp [shapeDiv, Nat.div_self ha]
        · have : a < a * k := by
            have := Nat.mul_le_mul_left a (show 2 ≤ k by omega); omega
          simp [shapeDiv, Nat.mod_eq_of_lt this, Nat.pos_iff_ne_zero.mp ha,
            Nat.pos_iff_ne_zero.mp hr]
      have hnd : shapeDiv (a * k) a = k := by
        simp [shapeDiv, Nat.mul_div_cancel_left k ha]
      have hs : ∀ o, composeStep (a, ad) (o, e, a * k) = (o, e, k) := fun o => by
        simp [composeStep, hns, hnd]
      rw [hs] at hd ⊢
      exact composeFold_prod M out e k hd hk he
    · obtain ⟨hra, hq⟩ := hc.resolve_left h1
      obtain ⟨q, rfl⟩ := Nat.dvd_of_mod_eq_zero hra
      have hq0 : 0 < q := Nat.pos_of_ne_zero (by rintro rfl; simp at hq; omega)
      have hq1 : q ≠ 1 := by rintro rfl; simp at h1
      have hrq : r * q / r = q := Nat.mul_div_cancel_left q hr
      have hns : shapeDiv (r * q) r = q := by simp [shapeDiv, hrq]
      have hnd : shapeDiv r (r * q) = 1 := by
        have : r * q ≠ 0 := Nat.mul_ne_zero (by omega) (by omega)
        simp [shapeDiv, h1, this]
      rw [hrq] at hq
      by_cases e1 : e = 1
      · subst e1
        have hs : ∀ o, composeStep (r * q, ad) (o, 1, r) = (o, 1, 1) := fun o => by
          simp [composeStep, hns, hnd]
        rw [hs] at hd ⊢
        exact composeFold_prod M out 1 1 hd Nat.one_pos Nat.one_pos
      · by_cases eq : e ≤ q
        · have hm : min q e = e := Nat.min_eq_right eq
          have hs : ∀ o, composeStep (r * q, ad) (o, e, r) = (o ++ [(e, r * ad)], 1, 1) :=
            fun o => by
              have hee : shapeDiv e e = 1 := by simp [shapeDiv, Nat.div_self he]
              simp only [composeStep, hns, hnd, hm, hee]; simp [hq1, e1]
          rw [hs] at hd ⊢
          rw [composeFold_prod M _ 1 1 hd Nat.one_pos Nat.one_pos]
          simp [List.prod_append]
        · obtain ⟨t, rfl⟩ := Nat.dvd_of_mod_eq_zero (hq.resolve_left eq)
          have hm : min q (q * t) = q := Nat.min_eq_left (by omega)
          have ht : 0 < t := Nat.pos_of_ne_zero (by rintro rfl; simp at he)
          have hs : ∀ o, composeStep (r * q, ad) (o, q * t, r) = (o ++ [(q, r * ad)], t, 1) :=
            fun o => by
              have hee : shapeDiv (q * t) q = t := by
                simp [shapeDiv, Nat.mul_div_cancel_left t hq0]
              simp only [composeStep, hns, hnd, hm, hee]; simp [hq1, e1]
          rw [hs] at hd ⊢
          rw [composeFold_prod M _ t 1 hd Nat.one_pos ht]
          simp [List.prod_append, Nat.mul_assoc]

/-- The steps of `composeLeaf` keep the offsets: after the steps from the modes `M` of the outer
layout, starting from the modes `out` emitted so far, the extent `e` and the stride `r`, the
emitted modes followed by the last mode of extent and stride what is left (times the outer
layout's last stride `L.2`) give the index `i + P * j` (`P` the size of `out`, `i < P`, `j < e`)
the offset `out` gives `i` plus the offset that `M` followed by `L` gives `j * r`. For every
list of modes under `composeDiv`, positive stride, and `j * r` below the size of `M` and `L`. -/
theorem composeFold_dot (L : Nat × Nat) : ∀ (M out : List (Nat × Nat)) (e r : Nat),
    composeDiv M (e, r) = true → 0 < r → ∀ j i, j < e → i < (out.map Prod.fst).prod →
    j * r < ((M ++ [L]).map Prod.fst).prod →
    dotColex ((M.foldl (fun st cd => composeStep cd st) (out, e, r)).1 ++
        [((M.foldl (fun st cd => composeStep cd st) (out, e, r)).2.1,
          (M.foldl (fun st cd => composeStep cd st) (out, e, r)).2.2 * L.2)])
        (i + (out.map Prod.fst).prod * j) =
      dotColex out i + dotColex (M ++ [L]) (j * r)
  | [], out, e, r, _, _, j, i, hj, hi, hb => by
    have hP : 0 < (out.map Prod.fst).prod := by omega
    have dm : dotColex out (i + (out.map Prod.fst).prod * j) = dotColex out i := by
      rw [← dotColex_mod, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt hi]
    simp only [List.foldl_nil, List.nil_append] at hb ⊢
    rw [dotColex_append, dm, Nat.add_mul_div_left _ _ hP, Nat.div_eq_of_lt hi, Nat.zero_add]
    simp only [List.map_cons, List.map_nil, List.prod_cons, List.prod_nil, Nat.mul_one] at hb
    simp [dotColex, colex, Nat.mod_eq_of_lt hj, Nat.mod_eq_of_lt hb, Nat.mul_assoc]
  | (a, ad) :: M, out, e, r, hd, hr, j, i, hj, hi, hb => by
    simp only [composeDiv, Bool.and_eq_true, Bool.or_eq_true, beq_iff_eq,
      decide_eq_true_eq] at hd
    obtain ⟨hc, hd⟩ := hd
    have hP : 0 < (out.map Prod.fst).prod := by omega
    have dm : ∀ x, dotColex out (i + (out.map Prod.fst).prod * x) = dotColex out i := fun x => by
      rw [← dotColex_mod, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt hi]
    have hX : ((M ++ [L]).map Prod.fst).prod ≠ 0 := by
      rintro h; simp only [List.cons_append, List.map_cons, List.prod_cons, h, Nat.mul_zero] at hb
      omega
    have hcons : ∀ x, dotColex ((a, ad) :: M ++ [L]) x =
        x % a * ad + dotColex (M ++ [L]) (x / a) := fun x => by
      rw [List.cons_append, ← List.singleton_append, dotColex_append]
      simp [dotColex, colex]
    simp only [List.cons_append, List.map_cons, List.prod_cons] at hb
    simp only [List.foldl_cons]
    rw [hcons]
    by_cases h1 : r % a = 0
    · obtain ⟨k, rfl⟩ := Nat.dvd_of_mod_eq_zero h1
      have ha : 0 < a := Nat.pos_of_ne_zero (by rintro rfl; simp at hr)
      have hk : 0 < k := Nat.pos_of_ne_zero (by rintro rfl; simp at hr)
      have hns : shapeDiv a (a * k) = 1 := by
        by_cases k1 : k = 1
        · subst k1; simp [shapeDiv, Nat.div_self ha]
        · have : a < a * k := by
            have := Nat.mul_le_mul_left a (show 2 ≤ k by omega); omega
          simp [shapeDiv, Nat.mod_eq_of_lt this, Nat.pos_iff_ne_zero.mp ha,
            Nat.pos_iff_ne_zero.mp hr]
      have hnd : shapeDiv (a * k) a = k := by
        simp [shapeDiv, Nat.mul_div_cancel_left k ha]
      have hs : ∀ o, composeStep (a, ad) (o, e, a * k) = (o, e, k) := fun o => by
        simp [composeStep, hns, hnd]
      rw [hs] at hd ⊢
      have e1 : j * (a * k) = a * (j * k) := by rw [Nat.mul_left_comm]
      rw [e1, Nat.mul_mod_right, Nat.zero_mul, Nat.zero_add, Nat.mul_div_cancel_left _ ha]
      rw [e1] at hb
      exact composeFold_dot L M out e k hd hk j i hj hi (Nat.lt_of_mul_lt_mul_left hb)
    · obtain ⟨hra, hq⟩ := hc.resolve_left h1
      obtain ⟨q, rfl⟩ := Nat.dvd_of_mod_eq_zero hra
      have hq0 : 0 < q := Nat.pos_of_ne_zero (by rintro rfl; simp at hq; omega)
      have hq1 : q ≠ 1 := by rintro rfl; simp at h1
      have hrq : r * q / r = q := Nat.mul_div_cancel_left q hr
      have hns : shapeDiv (r * q) r = q := by simp [shapeDiv, hrq]
      have hnd : shapeDiv r (r * q) = 1 := by
        have : r * q ≠ 0 := Nat.mul_ne_zero (by omega) (by omega)
        simp [shapeDiv, h1, this]
      rw [hrq] at hq
      by_cases e1 : e = 1
      · subst e1
        have j0 : j = 0 := by omega
        subst j0
        have hs : ∀ o, composeStep (r * q, ad) (o, 1, r) = (o, 1, 1) := fun o => by
          simp [composeStep, hns, hnd]
        rw [hs] at hd ⊢
        have := composeFold_dot L M out 1 1 hd Nat.one_pos 0 i Nat.one_pos hi
          (Nat.pos_of_ne_zero hX)
        simp only [Nat.mul_zero, Nat.add_zero, Nat.zero_mul, Nat.zero_mod, Nat.zero_div] at this ⊢
        rw [this]; simp [dotColex_zero]
      · by_cases eq : e ≤ q
        · have hm : min q e = e := Nat.min_eq_right eq
          have hs : ∀ o, composeStep (r * q, ad) (o, e, r) = (o ++ [(e, r * ad)], 1, 1) :=
            fun o => by
              have hee : shapeDiv e e = 1 := by simp [shapeDiv, Nat.div_self (by omega : 0 < e)]
              simp only [composeStep, hns, hnd, hm, hee]; simp [hq1, e1]
          rw [hs] at hd ⊢
          have hlt : i + (out.map Prod.fst).prod * j <
              ((out ++ [(e, r * ad)]).map Prod.fst).prod := by
            have := Nat.mul_le_mul_left (out.map Prod.fst).prod (show j + 1 ≤ e by omega)
            simp only [List.map_append, List.prod_append, List.map_cons, List.map_nil,
              List.prod_cons, List.prod_nil, Nat.mul_one]
            rw [Nat.mul_add, Nat.mul_one] at this; omega
          have := composeFold_dot L M _ 1 1 hd Nat.one_pos 0 _ Nat.one_pos hlt
            (Nat.pos_of_ne_zero hX)
          simp only [Nat.mul_zero, Nat.add_zero, Nat.zero_mul] at this
          rw [this, dotColex_zero, dotColex_append, dm, Nat.add_mul_div_left _ _ hP,
            Nat.div_eq_of_lt hi, Nat.zero_add]
          have hjq : j * r < r * q := by
            have := Nat.mul_le_mul_right r (show j + 1 ≤ q by omega)
            rw [Nat.add_mul, Nat.one_mul, Nat.mul_comm q r] at this; omega
          rw [Nat.mod_eq_of_lt hjq, Nat.div_eq_of_lt hjq, dotColex_zero]
          simp [dotColex, colex, Nat.mod_eq_of_lt hj, Nat.mul_assoc]
        · obtain ⟨t, rfl⟩ := Nat.dvd_of_mod_eq_zero (hq.resolve_left eq)
          have hm : min q (q * t) = q := Nat.min_eq_left (by omega)
          have hs : ∀ o, composeStep (r * q, ad) (o, q * t, r) = (o ++ [(q, r * ad)], t, 1) :=
            fun o => by
              have hee : shapeDiv (q * t) q = t := by
                simp [shapeDiv, Nat.mul_div_cancel_left t hq0]
              simp only [composeStep, hns, hnd, hm, hee]; simp [hq1, e1]
          rw [hs] at hd ⊢
          have hlt : i + (out.map Prod.fst).prod * (j % q) <
              ((out ++ [(q, r * ad)]).map Prod.fst).prod := by
            have := Nat.mul_le_mul_left (out.map Prod.fst).prod
              (show j % q + 1 ≤ q from Nat.mod_lt _ hq0)
            simp only [List.map_append, List.prod_append, List.map_cons, List.map_nil,
              List.prod_cons, List.prod_nil, Nat.mul_one]
            rw [Nat.mul_add, Nat.mul_one] at this; omega
          have hjt : j / q < t := (Nat.div_lt_iff_lt_mul hq0).2 (by rw [Nat.mul_comm]; exact hj)
          have hb' : j / q * 1 < ((M ++ [L]).map Prod.fst).prod := by
            rw [Nat.mul_one, Nat.div_lt_iff_lt_mul hq0]
            have : j * r < (((M ++ [L]).map Prod.fst).prod * q) * r := by
              rw [Nat.mul_assoc, Nat.mul_comm q r, Nat.mul_comm _ (r * q)]; exact hb
            exact Nat.lt_of_mul_lt_mul_right this
          have := composeFold_dot L M _ t 1 hd Nat.one_pos (j / q) _ hjt hlt hb'
          have hidx : i + (out.map Prod.fst).prod * j = i + (out.map Prod.fst).prod * (j % q) +
              ((out ++ [(q, r * ad)]).map Prod.fst).prod * (j / q) := by
            simp only [List.map_append, List.prod_append, List.map_cons, List.map_nil,
              List.prod_cons, List.prod_nil, Nat.mul_one]
            rw [Nat.mul_assoc, Nat.add_assoc, ← Nat.mul_add, Nat.mod_add_div]
          rw [hidx, this, dotColex_append, dm, Nat.add_mul_div_left _ _ hP, Nat.div_eq_of_lt hi,
            Nat.zero_add, Nat.mul_comm r q, Nat.mul_mod_mul_right, Nat.mul_div_mul_right _ _ hr]
          simp [dotColex, colex, Nat.mul_assoc, Nat.add_assoc]

/-- **Composing one leaf** (composition card): for every list `A` of (extent, stride) modes and
every leaf of extent `s > 0` and stride `d` that meets `composeDiv` on the modes of `A` but the
last, the modes `composeLeaf` returns have the extents' product `s`, and give every index `c < s`
with `c * d` below the size of `A` the offset that `A` gives `c * d`. A stride 0 meets
`composeDiv` and composes to the single mode `(s, 0)`. -/
theorem composeLeaf_prod_dot (A : List (Nat × Nat)) (s d : Nat) (hs : 0 < s)
    (hdiv : composeDiv A.dropLast (s, d) = true) :
    ((composeLeaf A s d).map Prod.fst).prod = s ∧ ∀ c, c < s →
      c * d < (A.map Prod.fst).prod → dotColex (composeLeaf A s d) c = dotColex A (c * d) := by
  rcases Nat.eq_zero_or_pos d with rfl | hd
  · refine ⟨by simp [composeLeaf], fun c _ _ => ?_⟩
    rw [Nat.mul_zero, dotColex_zero]
    simp [composeLeaf, dotColex, colex]
  rcases List.eq_nil_or_concat A with rfl | ⟨M, L, rfl⟩
  · refine ⟨by simp [composeLeaf, Nat.pos_iff_ne_zero.mp hd], fun c _ hb => ?_⟩
    simp [composeLeaf, Nat.pos_iff_ne_zero.mp hd, dotColex, colex]
  · simp only [List.concat_eq_append, List.dropLast_concat] at hdiv
    have hp := composeFold_prod M [] s d hdiv hd hs
    have hdot := fun c hc hb => composeFold_dot L M [] s d hdiv hd c 0 hc Nat.one_pos hb
    simp only [List.concat_eq_append, composeLeaf, Nat.pos_iff_ne_zero.mp hd, ↓reduceIte,
      List.dropLast_concat, List.getLast?_concat, Option.map_some, Option.getD_some]
    generalize M.foldl (fun st cd => composeStep cd st) ([], s, d) = F at hp hdot ⊢
    simp only [List.map_nil, List.prod_nil, Nat.one_mul, Nat.zero_add,
      show dotColex [] 0 = 0 from rfl] at hp hdot
    by_cases h : F.2.1 ≠ 1 ∨ F.1 = []
    · simp only [h, ↓reduceIte]
      refine ⟨by simp [List.prod_append, hp], fun c hc hb => ?_⟩
      rw [hdot c hc hb]
    · simp only [h, ↓reduceIte]
      have h1 : F.2.1 = 1 := by omega
      refine ⟨by rw [← hp, h1, Nat.mul_one], fun c hc hb => ?_⟩
      rw [← hdot c hc hb, dotColex_append]
      simp only [dotColex, colex, h1, List.map_cons, List.map_nil, List.zipWith_cons_cons,
        List.zipWith_nil_left, List.sum_cons, List.sum_nil, Nat.mod_one, Nat.zero_mul,
        Nat.add_zero]

/-- Composition leaf by leaf, on lists: for the flattened modes `ms` of an inner layout, each
meeting `composeDiv` on the modes of `A` but the last, and an index `v` below their size whose
offset `dotColex ms v` is below the size of `A`, the modes that `composeLeaf` gives the leaves,
concatenated, have the size of `ms` and give `v` the sum over the leaves of `F` of the leaf's
digit times its stride, for every `F` that agrees with `dotColex A` below the size of `A`. -/
theorem composeLeaf_flatMap (A : List (Nat × Nat)) (F : Nat → Nat)
    (hF : ∀ t, t < (A.map Prod.fst).prod → F t = dotColex A t) :
    ∀ (ms : List (Nat × Nat)) (v : Nat), (∀ m ∈ ms, composeDiv A.dropLast m = true) →
    v < (ms.map Prod.fst).prod → dotColex ms v < (A.map Prod.fst).prod →
    ((ms.flatMap fun m => composeLeaf A m.1 m.2).map Prod.fst).prod = (ms.map Prod.fst).prod ∧
      dotColex (ms.flatMap fun m => composeLeaf A m.1 m.2) v =
        (List.zipWith (fun x m => F (x * m.2)) (colex v (ms.map Prod.fst)) ms).sum
  | [], v, _, _, _ => by simp [dotColex, colex]
  | m :: ms, v, hd, hv, hb => by
    simp only [List.mem_cons, forall_eq_or_imp] at hd
    simp only [List.map_cons, List.prod_cons] at hv
    have hm : 0 < m.1 := Nat.pos_of_ne_zero (by intro h; simp [h] at hv)
    have hv' : v / m.1 < (ms.map Prod.fst).prod := by
      rw [Nat.div_lt_iff_lt_mul hm, Nat.mul_comm]; exact hv
    have hcons : dotColex (m :: ms) v = v % m.1 * m.2 + dotColex ms (v / m.1) := by
      rw [← List.singleton_append, dotColex_append]; simp [dotColex, colex]
    rw [hcons] at hb
    obtain ⟨p1, d1⟩ := composeLeaf_prod_dot A m.1 m.2 hm hd.1
    obtain ⟨p2, d2⟩ := composeLeaf_flatMap A F hF ms (v / m.1) hd.2 hv' (by omega)
    simp only [List.flatMap_cons, List.map_append, List.prod_append, p1, p2, List.map_cons,
      List.prod_cons, true_and]
    rw [dotColex_append, p1, d2, ← dotColex_mod, p1, d1 _ (Nat.mod_lt _ hm) (by omega),
      ← hF _ (by omega)]
    simp [colex]

/-- The composite's flattened modes are the modes that `composeLeaf` gives `B`'s flattened modes,
leaf by leaf, concatenated, and its shape and stride are congruent. For every `A` and every `B`
whose shape and stride are congruent, nested or flat. -/
theorem Lay.compose_modes (A B : Lay) (hB : congruentL B.shape B.stride = true) :
    (A.compose B).modes = B.modes.flatMap (fun m => composeLeaf A.modes m.1 m.2) ∧
      congruentL (A.compose B).shape (A.compose B).stride = true := by
  have key : ∀ ss ds : List Tup, congruentL ss ds = true →
      (List.zipWith (fun bs bd => ((leaves bs).zip (leaves bd)).flatMap
        (fun m => composeLeaf A.modes m.1 m.2)) ss ds).flatten =
        ((leavesL ss).zip (leavesL ds)).flatMap (fun m => composeLeaf A.modes m.1 m.2) := by
    intro ss
    induction ss with
    | nil => intro ds h; cases ds <;> simp_all [congruentL, leavesL]
    | cons s ss ih =>
      intro ds h
      cases ds with
      | nil => simp [congruentL] at h
      | cons d ds =>
        simp only [congruentL, Bool.and_eq_true] at h
        simp only [List.zipWith_cons_cons, List.flatten_cons, leavesL,
          List.zip_append (congruent_leaves_length s d h.1), List.flatMap_append, ih ds h.2]
  have hms : ∀ ms : List (List (Nat × Nat)),
      (leavesL (ms.map fun m => tup (m.map fun p => leaf p.1 true))).zip
        (leavesL (ms.map fun m => tup (m.map fun p => leaf p.2 true))) = ms.flatten ∧
      congruentL (ms.map fun m => tup (m.map fun p => leaf p.1 true))
        (ms.map fun m => tup (m.map fun p => leaf p.2 true)) = true := by
    intro ms
    induction ms with
    | nil => simp [leavesL, congruentL]
    | cons m ms ih =>
      have h1 := Lay.modes_flat m
      have h2 := Lay.flat_congruent m
      simp only [Lay.modes, Lay.flat] at h1 h2
      simp only [List.map_cons, leavesL, leaves, congruentL, congruent, h2, Bool.true_and, ih.2,
        List.flatten_cons, and_true]
      rw [List.zip_append (by simp [leavesL_map_leaf]), h1, ih.1]
  obtain ⟨e1, e2⟩ := hms (List.zipWith (fun bs bd => ((leaves bs).zip (leaves bd)).flatMap
    (fun m => composeLeaf A.modes m.1 m.2)) B.shape B.stride)
  exact ⟨e1.trans (key _ _ hB), e2⟩

/-- **Composition, mode by mode** (composition card): for every layout `A` whose shape and stride
are congruent, every layout `B` whose shape and stride are congruent and whose flattened modes
each meet `composeDiv` on the flattened modes of `A` but the last, and every scalar coordinate
`v` below the size of `B` whose offset `B(v)` is below the size of `A`, the composite has the
size of `B`, and its offset of `v` is the sum over `B`'s flattened modes of `A`'s offset of the
mode's digit times its stride, the digits being `v`'s colexicographic digits against `B`'s
extents. For every shape of `A` and `B`, nested or flat. -/
theorem Lay.compose_sum (A B : Lay) (hA : congruentL A.shape A.stride = true)
    (hB : congruentL B.shape B.stride = true)
    (hdiv : ∀ m ∈ B.modes, composeDiv A.modes.dropLast m = true) (v : Nat) (b : Bool)
    (hv : v < B.size) (hb : B.call (leaf v b) < A.size) :
    (A.compose B).size = B.size ∧ (A.compose B).call (leaf v b) =
      (List.zipWith (fun x m => A.call (leaf (x * m.2) b)) (colex v (B.modes.map Prod.fst))
        B.modes).sum := by
  obtain ⟨hAp, hAc⟩ := A.modes_size_call hA
  obtain ⟨hBp, hBc⟩ := B.modes_size_call hB
  obtain ⟨hRm, hRc⟩ := Lay.compose_modes A B hB
  obtain ⟨hRp, hRd⟩ := (A.compose B).modes_size_call hRc
  rw [hBc v b hv] at hb
  obtain ⟨p, d⟩ := composeLeaf_flatMap A.modes (fun t => A.call (leaf t b))
    (fun t ht => hAc t b (by rw [← hAp]; exact ht)) B.modes v hdiv (by rw [hBp]; exact hv)
    (by rw [hAp]; exact hb)
  have hs : (A.compose B).size = B.size := by rw [← hRp, hRm, p, hBp]
  exact ⟨hs, by rw [hRd v b (by rw [hs]; exact hv), hRm, d]⟩

/-- `noCarry A ts` is `true` when the terms `ts` add without a carry against the extents `A`: at
each extent `a`, the sum of the terms' digits `t % a` is below `a`, and the same holds for the
quotients `t / a` against the remaining extents. Then the colexicographic digits of the sum are
the sums of the terms' digits, and `dotColex` adds over the terms (`dotColex_sum`). -/
def noCarry : List Nat → List Nat → Bool
  | [], _ => true
  | a :: A, ts => decide ((ts.map (· % a)).sum < a) && noCarry A (ts.map (· / a))

/-- A single term never carries against positive extents. -/
theorem noCarry_one : ∀ (A : List Nat) (t : Nat), (∀ a ∈ A, 0 < a) → noCarry A [t] = true
  | [], _, _ => rfl
  | a :: A, t, h => by
    simp only [List.mem_cons, forall_eq_or_imp] at h
    simp [noCarry, Nat.mod_lt _ h.1, noCarry_one A (t / a) h.2]

/-- For every `a` and every list of numbers, the sum is `a` times the sum of the quotients by `a`
plus the sum of the remainders. -/
theorem sum_divMod (a : Nat) : ∀ us : List Nat,
    us.sum = a * (us.map (· / a)).sum + (us.map (· % a)).sum
  | [] => rfl
  | t :: us => by
    simp only [List.sum_cons, List.map_cons, Nat.mul_add, sum_divMod a us]
    have := Nat.div_add_mod t a
    omega

/-- **A layout adds over terms that do not carry** (composition card): for every list `A` of
(extent, stride) modes and every list of terms `ts` that `noCarry` accepts against `A`'s
extents, the offset of the sum of the terms is the sum of their offsets. -/
theorem dotColex_sum : ∀ (A : List (Nat × Nat)) (ts : List Nat),
    noCarry (A.map Prod.fst) ts = true → dotColex A ts.sum = (ts.map (dotColex A)).sum
  | [], ts, _ => by
    have z : ∀ us : List Nat, (us.map (dotColex [])).sum = 0 := by
      intro us
      induction us with
      | nil => rfl
      | cons t us ih => simp only [List.map_cons, List.sum_cons, ih]; rfl
    rw [z]; rfl
  | (a, e) :: A, ts, h => by
    simp only [List.map_cons, noCarry, Bool.and_eq_true, decide_eq_true_eq] at h
    have hcons : ∀ x, dotColex ((a, e) :: A) x = x % a * e + dotColex A (x / a) := fun x => by
      rw [← List.singleton_append, dotColex_append]; simp [dotColex, colex]
    have ha : 0 < a := by omega
    have h1 : ts.sum % a = (ts.map (· % a)).sum := by
      rw [sum_divMod a ts, Nat.mul_add_mod, Nat.mod_eq_of_lt h.1]
    have h2 : ts.sum / a = (ts.map (· / a)).sum := by
      rw [sum_divMod a ts, Nat.mul_add_div ha, Nat.div_eq_of_lt h.1, Nat.add_zero]
    have hr : ∀ us : List Nat, (us.map (dotColex ((a, e) :: A))).sum =
        (us.map (· % a)).sum * e + ((us.map (· / a)).map (dotColex A)).sum := by
      intro us
      induction us with
      | nil => simp
      | cons t us ih => simp only [List.map_cons, List.sum_cons, hcons, ih, Nat.add_mul]; omega
    rw [hcons, h1, h2, dotColex_sum A _ h.2, hr]

/-- **The composition law** (composition card): for every layout `A` whose shape and stride are
congruent, every layout `B` whose shape and stride are congruent and whose flattened modes each
meet `composeDiv` on the flattened modes of `A` but the last, and every scalar coordinate `v`
below the size of `B` whose offset `B(v)` is below the size of `A` and whose terms (each mode's
digit times its stride, which add up to `B(v)`) do not carry against `A`'s extents
(`noCarry`), the composite gives `v` the offset that `A` gives `B(v)`. For every shape of `A`
and `B`, nested or flat. A `B` of one mode meets `noCarry` at every `v` (`noCarry_one`: `A`'s
extents are positive, as `B(v) < A.size` requires). Mojo's cosize assert,
`B.cosize ≤ A.size`, gives `B(v) < A.size`. -/
theorem Lay.compose_call (A B : Lay) (hA : congruentL A.shape A.stride = true)
    (hB : congruentL B.shape B.stride = true)
    (hdiv : ∀ m ∈ B.modes, composeDiv A.modes.dropLast m = true) (v : Nat) (b : Bool)
    (hv : v < B.size) (hb : B.call (leaf v b) < A.size)
    (hnc : noCarry (A.modes.map Prod.fst)
      (List.zipWith (fun x m => x * m.2) (colex v (B.modes.map Prod.fst)) B.modes) = true) :
    (A.compose B).call (leaf v b) = A.call (leaf (B.call (leaf v b)) b) := by
  obtain ⟨hAp, hAc⟩ := A.modes_size_call hA
  obtain ⟨hBp, hBc⟩ := B.modes_size_call hB
  obtain ⟨hRm, hRc⟩ := Lay.compose_modes A B hB
  obtain ⟨hRp, hRd⟩ := (A.compose B).modes_size_call hRc
  rw [hBc v b hv] at hb ⊢
  obtain ⟨p, d⟩ := composeLeaf_flatMap A.modes (dotColex A.modes) (fun _ _ => rfl) B.modes v
    hdiv (by rw [hBp]; exact hv) (by rw [hAp]; exact hb)
  have hs : (A.compose B).size = B.size := by rw [← hRp, hRm, p, hBp]
  have ht : dotColex B.modes v =
      (List.zipWith (fun x m => x * m.2) (colex v (B.modes.map Prod.fst)) B.modes).sum := by
    simp [dotColex, List.zipWith_map_right]
  rw [hRd v b (by rw [hs]; exact hv), hRm, d, hAc _ b hb, ht, dotColex_sum _ _ hnc,
    List.map_zipWith]

/-- `carryFree A Ts` is `true` when, at each extent `a` of `A`, the largest remainders `t % a`
of the lists of `Ts` add up to less than `a`, the same holds for the quotients `t / a` against
the remaining extents, and after the last extent every quotient is `0`. Then every choice of one
term from each list adds without carry against `A` and stays below the product of `A`
(`carryFree_pick`). It costs the total length of `Ts`, not the number of choices. -/
def carryFree : List Nat → List (List Nat) → Bool
  | [], Ts => Ts.all (·.all (· == 0))
  | a :: A, Ts => decide ((Ts.map fun T => (T.map (· % a)).max?.getD 0).sum < a) &&
      carryFree A (Ts.map (·.map (· / a)))

/-- For every list of extents `A`, every list of lists `Ts` that `carryFree` accepts against
`A`, and every list `ts` of one term from each list of `Ts` (same length, each term a member of
its list), the terms do not carry against `A` (`noCarry`) and their sum is below the product
of `A`. -/
theorem carryFree_pick : ∀ (A : List Nat) (Ts : List (List Nat)) (ts : List Nat),
    carryFree A Ts = true → ts.length = Ts.length → (∀ p ∈ ts.zip Ts, p.1 ∈ p.2) →
    noCarry A ts = true ∧ ts.sum < A.prod
  | [], Ts, ts, h, hl, hm => by
    refine ⟨rfl, ?_⟩
    have z : ∀ (ts : List Nat) (Ts : List (List Nat)), Ts.all (·.all (· == 0)) = true →
        ts.length = Ts.length → (∀ p ∈ ts.zip Ts, p.1 ∈ p.2) → ts.sum = 0 := by
      intro ts
      induction ts with
      | nil => intros; rfl
      | cons t ts ih =>
        intro Ts h hl hm
        cases Ts with
        | nil => simp at hl
        | cons T Ts =>
          simp only [List.all_cons, Bool.and_eq_true] at h
          have ht := List.all_eq_true.1 h.1 t (hm (t, T) (by simp))
          simp only [beq_iff_eq] at ht
          simp only [List.sum_cons, ht, ih Ts h.2 (by simpa using hl)
            (fun p hp => hm p (by simp [hp]))]
    simp [z ts Ts h hl hm]
  | a :: A, Ts, ts, h, hl, hm => by
    simp only [carryFree, Bool.and_eq_true, decide_eq_true_eq] at h
    have hle : ∀ (ts : List Nat) (Ts : List (List Nat)), ts.length = Ts.length →
        (∀ p ∈ ts.zip Ts, p.1 ∈ p.2) →
        (ts.map (· % a)).sum ≤ (Ts.map fun T => (T.map (· % a)).max?.getD 0).sum := by
      intro ts
      induction ts with
      | nil => intros; simp
      | cons t ts ih =>
        intro Ts hl hm
        cases Ts with
        | nil => simp at hl
        | cons T Ts =>
          simp only [List.map_cons, List.sum_cons]
          exact Nat.add_le_add
            (List.le_max?_getD_of_mem (List.mem_map_of_mem (hm (t, T) (by simp))))
            (ih Ts (by simpa using hl) (fun p hp => hm p (by simp [hp])))
    have hr := Nat.lt_of_le_of_lt (hle ts Ts hl hm) h.1
    obtain ⟨hn, hq⟩ := carryFree_pick A _ (ts.map (· / a)) h.2 (by simpa using hl) (by
      intro p hp
      rw [List.zip_map] at hp
      obtain ⟨q, hq, rfl⟩ := List.mem_map.1 hp
      exact List.mem_map_of_mem (hm q hq))
    refine ⟨by simp [noCarry, hr, hn], ?_⟩
    have hP := Nat.mul_le_mul_left a (Nat.succ_le_of_lt hq)
    rw [sum_divMod a ts, List.prod_cons]
    rw [Nat.mul_succ] at hP
    omega

/-- For every list of (extent, stride) modes and every `v` below the product of the extents,
each term of `v` (its colexicographic digit against the extents times the mode's stride) is a
multiple of its mode's stride by a number below its mode's extent. -/
theorem colex_pick : ∀ (ms : List (Nat × Nat)) (v : Nat), v < (ms.map Prod.fst).prod →
    ∀ p ∈ (List.zipWith (fun x m => x * m.2) (colex v (ms.map Prod.fst)) ms).zip
      (ms.map fun m => (List.range m.1).map (· * m.2)), p.1 ∈ p.2
  | [], _, _ => by simp
  | (s, d) :: ms, v, hv => by
    simp only [List.map_cons, List.prod_cons] at hv
    have hs : 0 < s := Nat.pos_of_ne_zero (by rintro rfl; simp at hv)
    intro p hp
    simp only [List.map_cons, colex, List.zipWith_cons_cons, List.zip_cons_cons,
      List.mem_cons] at hp
    rcases hp with rfl | hp
    · exact List.mem_map.2 ⟨v % s, List.mem_range.2 (Nat.mod_lt v hs), rfl⟩
    · exact colex_pick ms (v / s)
        ((Nat.div_lt_iff_lt_mul hs).2 (by rw [Nat.mul_comm]; exact hv)) p hp

/-- **The composition law at every coordinate** (composition card): for every layout `A` whose
shape and stride are congruent, and every layout `B` whose shape and stride are congruent, whose
flattened modes each meet `composeDiv` on the flattened modes of `A` but the last, and whose
term lists (for each flattened mode `(s, d)` of `B`, the multiples `x * d` for `x < s`) are
`carryFree` against `A`'s extents, the composite gives every scalar coordinate `v` below the
size of `B` the offset that `A` gives `B(v)`. The premises are on `A` and `B` alone: `carryFree`
gives at every `v` both `B(v) < A.size` and `noCarry`, the premises of `Lay.compose_call` at
`v`. It is sufficient, not shown necessary. For every shape of `A` and `B`, nested or flat. -/
theorem Lay.compose_all (A B : Lay) (hA : congruentL A.shape A.stride = true)
    (hB : congruentL B.shape B.stride = true)
    (hdiv : ∀ m ∈ B.modes, composeDiv A.modes.dropLast m = true)
    (hcf : carryFree (A.modes.map Prod.fst)
      (B.modes.map fun m => (List.range m.1).map (· * m.2)) = true)
    (v : Nat) (b : Bool) (hv : v < B.size) :
    (A.compose B).call (leaf v b) = A.call (leaf (B.call (leaf v b)) b) := by
  obtain ⟨hAp, -⟩ := A.modes_size_call hA
  obtain ⟨hBp, hBc⟩ := B.modes_size_call hB
  have ht : dotColex B.modes v =
      (List.zipWith (fun x m => x * m.2) (colex v (B.modes.map Prod.fst)) B.modes).sum := by
    simp [dotColex, List.zipWith_map_right]
  obtain ⟨hn, hs⟩ := carryFree_pick _ _ _ hcf (by simp [colex_length])
    (colex_pick B.modes v (by rw [hBp]; exact hv))
  exact Lay.compose_call A B hA hB hdiv v b hv (by rw [hBc v b hv, ht, ← hAp]; exact hs) hn

end GPUProof.Layout
