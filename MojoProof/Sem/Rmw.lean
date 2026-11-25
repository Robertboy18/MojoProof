import MojoProof.Sem.Trace

/-!
# Two atomic updates commute, on values

The part about values of L10 in docs/proofs/schedule.md: two `atomicrmw`s of one admitted
operation give the same value in either order, for every width.

For every operation `Stmt.checkAtomic` admits (`RmwOp.commutes`), every width `w` and all scalars
`v x y` of width `w` (bits of width `w`, poison or undef, `Val.Scalar`), updating `v` by `x` and
then by `y` with `rmw w op` gives the same fault or the same value as updating it by `y` and then by
`x` (`rmw_comm`). If each update succeeds from `v`, for all operands `x y` (as `Mem.update` needs:
it does not check its operand), each result updated by the other operand succeeds, and the two give
the same value (`rmw_comm_of_ok`); an update that succeeds is by an operation `Stmt.checkAtomic`
admits (`rmw_commutes`), of a value and by an operand neither undef (`rmw_undef`), and from a scalar
gives a scalar of the same width (`rmw_scalar`); an update of a scalar by a scalar of width `w`,
neither undef, succeeds (`rmw_ok`). This is what `Access.conflict` relies on when it exempts two
`atomicrmw`s of one commuting operation (`RmwOp.commutes`) on the same bytes from racing. The
part about memory (two updates at one pointer, in either order, give the same blocks) is in
MojoProof/Sem/Confluence.lean.

The proof is done once for every operator that propagates undef and poison as LLVM's integer
operators do (`Lifts`, `Lifts.comm`, `Lifts.scalar`, `Lifts.ok`, `Lifts.comm_of_ok`) and whose
operation on words is right-commutative. Its instances are `intBin` with `add`, `and`, `or`,
`xor` (`intBin_lifts`) and `intMinMax` (`intMinMax_lifts`), whose right-commutativity is
`select_comm` for every strict order that an injective map to `Int` reads (`minmax_comm`, signed
and unsigned); `rmw_lifts` gives one for every operation `Stmt.checkAtomic` admits.

For a list of updates (docs/proofs/reduction.md): for every admitted operation, width and scalar,
two lists of scalar operands that are permutations of each other give the same fault or the same
value (`rmw_perm`, by `rmw_comm` and `rmw_scalar`). For `add` on words of width `w`, every order of
the words `xs` updates the word `a` to `a + xs.sum` (`rmw_add_perm`): the output word of an atomic
sum does not depend on the order in which the blocks of threads reach it, for every number of
blocks and every word of each. Instances: MojoProofTest/Shared.lean.
-/

namespace MojoProof.Sem

open LLVM

/-- `F` acts on values as LLVM's integer operators do with the operation `g` on words of width
`w`: a use of undef faults, poison absorbs, and two words give the word `g a b`; from a word it
succeeds only with a scalar of width `w`, and from poison it gives only poison. -/
structure Lifts (w : Nat) (F : Val → Val → Except Fault Val)
    (g : BitVec w → BitVec w → BitVec w) : Prop where
  /-- Builds `Lifts` from its seven fields. -/
  mk ::
  /-- Two words give the word `g a b`. -/
  bits : ∀ a b, F (.bits w a) (.bits w b) = .ok (.bits w (g a b))
  /-- `undef` on the left faults. -/
  undef_l : ∀ x, F .undef x = .error (.unsupported "use of undef")
  /-- `undef` on the right faults. -/
  undef_r : ∀ v, F v .undef = .error (.unsupported "use of undef")
  /-- Poison on the left and a word give poison. -/
  poison_l : ∀ b, F .poison (.bits w b) = .ok .poison
  /-- Poison on the right gives poison, unless the left is `undef`. -/
  poison_r : ∀ v, v ≠ .undef → F v .poison = .ok .poison
  /-- From a word, a success means the right operand is a scalar of width `w`. -/
  scalar_r : ∀ a x r, F (.bits w a) x = .ok r → x.Scalar w
  /-- From poison, a success gives poison. -/
  poison_ok : ∀ x r, F .poison x = .ok r → r = .poison

/-- If `g` is right-commutative, two updates of a scalar by `F` commute: the same fault or the
same value in either order. -/
theorem Lifts.comm {w : Nat} {F : Val → Val → Except Fault Val}
    {g : BitVec w → BitVec w → BitVec w} (h : Lifts w F g) (hg : ∀ a b c, g (g a b) c = g (g a c) b)
    {v x y : Val} (hv : v.Scalar w) (hx : x.Scalar w) (hy : y.Scalar w) :
    (F v x >>= (F · y)) = (F v y >>= (F · x)) := by
  rcases hv with ⟨a, rfl⟩ | rfl | rfl <;> rcases hx with ⟨b, rfl⟩ | rfl | rfl <;>
    rcases hy with ⟨c, rfl⟩ | rfl | rfl <;>
    simp [bind, Except.bind, h.bits, h.undef_l, h.undef_r, h.poison_l, h.poison_r, hg]

/-- An update of a scalar of width `w` by `F` that succeeds gives a scalar of width `w`. -/
theorem Lifts.scalar {w : Nat} {F : Val → Val → Except Fault Val}
    {g : BitVec w → BitVec w → BitVec w} (h : Lifts w F g) {v x r : Val} (hv : v.Scalar w)
    (hx : F v x = .ok r) : r.Scalar w := by
  rcases hv with ⟨a, rfl⟩ | rfl | rfl
  · rcases h.scalar_r _ _ _ hx with ⟨b, rfl⟩ | rfl | rfl
    · rw [h.bits] at hx
      cases hx
      exact .inl ⟨_, rfl⟩
    · rw [h.poison_r _ (by simp)] at hx
      cases hx
      exact .inr (.inl rfl)
    · rw [h.undef_r] at hx
      cases hx
  · exact .inr (.inl (h.poison_ok _ _ hx))
  · rw [h.undef_l] at hx
    cases hx

/-- `F` succeeds on two scalars of width `w` neither of which is undef. -/
theorem Lifts.ok {w : Nat} {F : Val → Val → Except Fault Val}
    {g : BitVec w → BitVec w → BitVec w} (h : Lifts w F g) {v x : Val} (hv : v.Scalar w)
    (hx : x.Scalar w) (hv' : v ≠ .undef) (hx' : x ≠ .undef) : ∃ r, F v x = .ok r := by
  rcases hv with ⟨a, rfl⟩ | rfl | rfl <;> rcases hx with ⟨b, rfl⟩ | rfl | rfl
  all_goals first
    | exact absurd rfl hv' | exact absurd rfl hx' | exact ⟨_, h.bits _ _⟩
    | exact ⟨_, h.poison_l _⟩ | exact ⟨_, h.poison_r _ hv'⟩

/-- If `g` is right-commutative, two updates of a scalar `v` by `F` that each succeed from it, by
`x` to `r` and by `y` to `r'`, whatever the operands: `r` updated by `y` and `r'` updated by `x`
succeed and give the same value. From a word the operands are scalars, and from poison both
orders give poison. -/
theorem Lifts.comm_of_ok {w : Nat} {F : Val → Val → Except Fault Val}
    {g : BitVec w → BitVec w → BitVec w} (h : Lifts w F g) (hg : ∀ a b c, g (g a b) c = g (g a c) b)
    {v x y r r' : Val} (hv : v.Scalar w) (hx : F v x = .ok r) (hy : F v y = .ok r') :
    ∃ u, F r y = .ok u ∧ F r' x = .ok u := by
  rcases hv with ⟨a, rfl⟩ | rfl | rfl
  · have hx' := h.scalar_r _ _ _ hx
    have hy' := h.scalar_r _ _ _ hy
    rcases hx' with ⟨b, rfl⟩ | rfl | rfl
    · rw [h.bits] at hx
      cases hx
      rcases hy' with ⟨d, rfl⟩ | rfl | rfl
      · rw [h.bits] at hy
        cases hy
        exact ⟨_, h.bits _ _, (h.bits _ _).trans (by rw [hg])⟩
      · rw [h.poison_r _ (by simp)] at hy
        cases hy
        exact ⟨_, h.poison_r _ (by simp), h.poison_l _⟩
      · rw [h.undef_r] at hy
        cases hy
    · rw [h.poison_r _ (by simp)] at hx
      cases hx
      rcases hy' with ⟨d, rfl⟩ | rfl | rfl
      · rw [h.bits] at hy
        cases hy
        exact ⟨_, h.poison_l _, h.poison_r _ (by simp)⟩
      · rw [h.poison_r _ (by simp)] at hy
        cases hy
        exact ⟨_, h.poison_r _ (by simp), h.poison_r _ (by simp)⟩
      · rw [h.undef_r] at hy
        cases hy
    · rw [h.undef_r] at hx
      cases hx
  · obtain rfl := h.poison_ok _ _ hx
    obtain rfl := h.poison_ok _ _ hy
    exact ⟨_, hy, hx⟩
  · rw [h.undef_l] at hx
    cases hx

/-- An integer operator that does not divide, without flags, whose result on words is `g`. -/
theorem intBin_lifts {w : Nat} {op : BinOp} {g : BitVec w → BitVec w → BitVec w}
    (hd : op.divides = false) (hb : ∀ a b, intBits op {} a b = .ok (.bits w (g a b))) :
    Lifts w (intBin w op {}) g where
  bits a b := by simp [intBin, hb]
  undef_l x := by cases x <;> rfl
  undef_r v := by cases v <;> rfl
  poison_l b := by simp [intBin, hd, pure, Except.pure]
  poison_r v hv := by cases v <;> simp_all [intBin, pure, Except.pure]
  scalar_r a x r h := by
    cases x with
    | bits w₂ b =>
      by_cases hw : w₂ = w
      · subst hw
        exact .inl ⟨b, rfl⟩
      · simp [intBin, hw] at h
    | poison => exact .inr (.inl rfl)
    | undef => exact .inr (.inr rfl)
    | _ => cases h
  poison_ok x r h := by
    cases x <;> simp [intBin, hd, pure, Except.pure] at h <;> exact h.symm

/-- Keeping the second of two values if `lt a b` is `max`, the first otherwise, is
right-commutative, for every strict order `lt` that an injective map to `Int` reads. -/
theorem select_comm {α : Type*} {f : α → Int} (hf : Function.Injective f) {lt : α → α → Bool}
    (hlt : ∀ a b, lt a b = decide (f a < f b)) (max : Bool) (a b c : α) :
    let s := fun a b => if lt a b == max then b else a
    s (s a b) c = s (s a c) b := by
  intro s
  apply hf
  simp only [s, hlt]
  cases max <;> split_ifs <;> simp_all <;> omega

/-- `smax`, `smin`, `umax` and `umin` propagate as LLVM's integer operators do. -/
theorem intMinMax_lifts {w : Nat} (signed max : Bool) :
    Lifts w (intMinMax signed max)
      (fun a b => if (if signed then a.slt b else a.ult b) == max then b else a) where
  bits a b := by simp [intMinMax, strict2, pure, Except.pure]
  undef_l x := by cases x <;> rfl
  undef_r v := by cases v <;> rfl
  poison_l b := rfl
  poison_r v hv := by cases v <;> simp_all [intMinMax, strict2, pure, Except.pure]
  scalar_r a x r h := by
    cases x with
    | bits w₂ b =>
      by_cases hw : w₂ = w
      · subst hw
        exact .inl ⟨b, rfl⟩
      · simp [intMinMax, strict2, hw] at h
    | poison => exact .inr (.inl rfl)
    | undef => exact .inr (.inr rfl)
    | _ => cases h
  poison_ok x r h := by
    cases x <;> simp [intMinMax, strict2, pure, Except.pure] at h <;> exact h.symm

/-- Signed and unsigned `max` and `min` on words are right-commutative. -/
theorem minmax_comm {w : Nat} (signed max : Bool) (a b c : BitVec w) :
    let g := fun a b : BitVec w => if (if signed then a.slt b else a.ult b) == max then b else a
    g (g a b) c = g (g a c) b := by
  cases signed
  · exact select_comm (f := fun a : BitVec w => (a.toNat : Int)) (lt := BitVec.ult)
      (fun a b h => BitVec.eq_of_toNat_eq (by simpa using h)) (fun a b => by simp [BitVec.ult])
      max a b c
  · exact select_comm (f := BitVec.toInt) (lt := BitVec.slt) (fun a b h => BitVec.eq_of_toInt_eq h)
      (fun a b => rfl) max a b c

/-- Every operation `Stmt.checkAtomic` admits acts on values of every width `w` as LLVM's integer
operators do, with a right-commutative operation on words. -/
theorem rmw_lifts {w : Nat} {op : RmwOp} (hop : op.commutes) :
    ∃ g : BitVec w → BitVec w → BitVec w,
      Lifts w (rmw w op) g ∧ ∀ a b c, g (g a b) c = g (g a c) b := by
  cases op <;> simp only [RmwOp.commutes] at hop <;> simp only [rmw] <;> first
    | exact ⟨_, intMinMax_lifts _ _, minmax_comm _ _⟩
    | exact ⟨_, intBin_lifts rfl fun _ _ => rfl, fun _ _ _ => by ac_rfl⟩
    | cases hop

/-- An update by `rmw` that succeeds is by an operation `Stmt.checkAtomic` admits. -/
theorem rmw_commutes {w : Nat} {op : RmwOp} {v x r : Val} (h : rmw w op v x = .ok r) :
    op.commutes = true := by
  cases op <;> first | rfl | cases h

/-- **L10, on values.** For every operation `Stmt.checkAtomic` admits and every width, two updates
of a scalar commute: updating `v` by `x` and then by `y` gives the same fault or the same value as
by `y` and then by `x`. -/
theorem rmw_comm {w : Nat} {op : RmwOp} (hop : op.commutes) {v x y : Val}
    (hv : v.Scalar w) (hx : x.Scalar w) (hy : y.Scalar w) :
    (rmw w op v x >>= (rmw w op · y)) = (rmw w op v y >>= (rmw w op · x)) := by
  obtain ⟨g, h, hg⟩ := rmw_lifts (w := w) hop
  exact h.comm hg hv hx hy

/-- An update of a scalar of width `w` by `rmw w op` that succeeds gives a scalar of width `w`. -/
theorem rmw_scalar {w : Nat} {op : RmwOp} {v x r : Val} (hv : v.Scalar w)
    (h : rmw w op v x = .ok r) : r.Scalar w := by
  obtain ⟨g, hl, -⟩ := rmw_lifts (w := w) (rmw_commutes h)
  exact hl.scalar hv h

/-- `rmw` faults on undef: an update by `rmw w op` that succeeds is of a value and by an operand
neither of which is undef. -/
theorem rmw_undef {w : Nat} {op : RmwOp} {v x r : Val} (h : rmw w op v x = .ok r) :
    v ≠ .undef ∧ x ≠ .undef := by
  obtain ⟨g, hl, -⟩ := rmw_lifts (w := w) (rmw_commutes h)
  constructor <;> rintro rfl
  · rw [hl.undef_l] at h
    cases h
  · rw [hl.undef_r] at h
    cases h

/-- For every operation `Stmt.checkAtomic` admits and every width `w`, an update of a scalar of
width `w` by one, neither undef, succeeds. -/
theorem rmw_ok {w : Nat} {op : RmwOp} (hop : op.commutes) {v x : Val} (hv : v.Scalar w)
    (hx : x.Scalar w) (hv' : v ≠ .undef) (hx' : x ≠ .undef) : ∃ r, rmw w op v x = .ok r :=
  (rmw_lifts (w := w) hop).choose_spec.1.ok hv hx hv' hx'

/-- **L10, on values, as a step has it.** For every width and operation, two updates of a scalar
`v` that each succeed from it, by `x` to `r` and by `y` to `r'`, for all operands: `r` updated by
`y` and `r'` updated by `x` succeed and give the same value. The operands need not be scalars of
width `w` (`Mem.update` does not check them), and `rmw w .max .poison (.ptr p)` succeeds. -/
theorem rmw_comm_of_ok {w : Nat} {op : RmwOp} {v x y r r' : Val} (hv : v.Scalar w)
    (hx : rmw w op v x = .ok r) (hy : rmw w op v y = .ok r') :
    ∃ u, rmw w op r y = .ok u ∧ rmw w op r' x = .ok u := by
  obtain ⟨g, hl, hg⟩ := rmw_lifts (w := w) (rmw_commutes hx)
  exact hl.comm_of_ok hg hv hx hy


/-- **Updates in any order give one value** (L10 for a list of updates). For every operation
`Stmt.checkAtomic` admits, every width `w`, every scalar `v` of width `w` and all lists `xs` and
`ys` of scalars of width `w` that are permutations of each other: updating `v` by `rmw w op` with
the operands in the order of `xs` gives the same fault or the same value as in the order of `ys`.
By induction on the permutation: a swap of two neighbours is `rmw_comm`, and an update of a scalar
that succeeds gives a scalar (`rmw_scalar`). -/
theorem rmw_perm {w : Nat} {op : RmwOp} (hop : op.commutes) {xs ys : List Val}
    (hp : xs.Perm ys) (hs : ∀ x ∈ xs, x.Scalar w) {v : Val} (hv : v.Scalar w) :
    xs.foldlM (rmw w op) v = ys.foldlM (rmw w op) v := by
  induction hp generalizing v with
  | nil => rfl
  | cons x _ ih =>
    simp only [List.foldlM_cons]
    cases e : rmw w op v x with
    | error => rfl
    | ok r => exact ih (fun y hy => hs y (.tail _ hy)) (rmw_scalar hv e)
  | swap x y l =>
    simp only [List.foldlM_cons, ← bind_assoc]
    rw [rmw_comm hop hv (hs y (by simp)) (hs x (by simp))]
  | trans h₁ _ ih₁ ih₂ => exact (ih₁ hs hv).trans (ih₂ (fun y hy => hs y (h₁.mem_iff.2 hy)) hv)

/-- **The words of an atomic sum in any order** (`atomicrmw add`). For every width `w`, word `a`
and lists `xs` and `ys` of words of width `w` that are permutations of each other: updating the
word `a` by `rmw w .add` with the words of `ys`, in that order, gives the word `a + xs.sum`. So a
reduction whose blocks of threads each add their word to one output word, in whatever order they
reach it, leaves the same word, for every number of blocks and every value of each. `rmw_perm`,
then the sum in the order of `xs`. -/
theorem rmw_add_perm {w : Nat} {xs ys : List (BitVec w)} (hp : ys.Perm xs) (a : BitVec w) :
    (ys.map (Val.bits w)).foldlM (rmw w .add) (.bits w a) = .ok (.bits w (a + xs.sum)) := by
  rw [rmw_perm rfl (hp.map _) (fun x hx => by
    obtain ⟨b, -, rfl⟩ := List.mem_map.1 hx
    exact .inl ⟨b, rfl⟩) (.inl ⟨a, rfl⟩)]
  clear hp
  induction xs generalizing a with
  | nil => simp [pure, Except.pure]
  | cons b xs ih =>
    have hab : rmw w .add (.bits w a) (.bits w b) = .ok (.bits w (a + b)) :=
      (intBin_lifts (g := (· + ·)) rfl fun _ _ => rfl).bits a b
    simp only [List.map_cons, List.foldlM_cons, List.sum_cons, hab, ← BitVec.add_assoc]
    exact ih (a + b)

end MojoProof.Sem
