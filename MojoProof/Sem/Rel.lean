import Batteries.Data.List.Basic

/-!
# Relations lifted to `Option`, `Except` and lists

Lemmas about core types, for every relation and all types. The skeleton relation
(MojoProof/Sem/Skeleton.lean) and the proofs that the semantics respects it use them; the step
proofs state a few more where they use them (MojoProof/Sem/SkelExec.lean,
MojoProof/Sem/SkelStep.lean and MojoProof/Sym/Payload.lean).

- `Option.Rel` (core): `Option.Rel.refl` and `Option.Rel.symm` (it is reflexive or symmetric
  when the relation is), `Option.Rel.map_eq` (a function equal on related values maps related
  options to equal ones) and `Option.Rel.getD` (related options with related defaults give related
  values). `Option.map_bind_bind`: two options combined in `do` notation give equal images under a
  map when the arguments do and the combination respects that.
- `Except.Rel R`: two results related by `R`, one fault on both sides or values related by `R`.
  It is reflexive when `R` is (`Except.Rel.refl`), and `bind`, `map`, `List.mapM` and
  `List.foldlM` respect it (`Except.Rel.bind`, `Except.Rel.map`, `Except.Rel.mapM`,
  `Except.Rel.foldlM`): with functions that give related results on related values, both sides
  give the same first fault or related results.
- `List.Forall₂` (lists related element by element): `List.zipIdx`, `List.zip` and `List.set`
  with related elements respect it (`List.Forall₂.zipIdx`, `List.Forall₂.zip`,
  `List.Forall₂.set`), and related lists are related by `Option.Rel` at every index
  (`List.Forall₂.getElem?`).
-/

namespace MojoProof.Sem

/-- `Option.Rel` of a reflexive relation is reflexive. -/
theorem _root_.Option.Rel.refl {α : Type} {R : α → α → Prop} (hR : ∀ x, R x x) :
    ∀ o : Option α, Option.Rel R o o
  | none => .none
  | some x => .some (hR x)

/-- `Option.Rel` of a symmetric relation is symmetric. -/
theorem _root_.Option.Rel.symm {α : Type} {R : α → α → Prop} {o₁ o₂ : Option α}
    (h : Option.Rel R o₁ o₂) (hR : ∀ {x y}, R x y → R y x) : Option.Rel R o₂ o₁ := by
  cases h with
  | none => exact .none
  | some h => exact .some (hR h)

/-- `Option.Rel R` maps to equality by a function that is equal on `R`-related values. -/
theorem _root_.Option.Rel.map_eq {α β : Type} {R : α → α → Prop} {f : α → β}
    {o₁ o₂ : Option α} (h : Option.Rel R o₁ o₂) (hf : ∀ {x y}, R x y → f x = f y) :
    o₁.map f = o₂.map f := by
  cases h with
  | none => rfl
  | some h => exact congrArg some (hf h)

/-- For every relation, related options with related defaults give related values. -/
theorem _root_.Option.Rel.getD {α β : Type} {R : α → β → Prop} {o₁ : Option α} {o₂ : Option β}
    (h : Option.Rel R o₁ o₂) {d₁ : α} {d₂ : β} (hd : R d₁ d₂) : R (o₁.getD d₁) (o₂.getD d₂) := by
  cases h with
  | none => exact hd
  | some h => exact h

/-- Two optional values combined by `g` give `f`-equal results from `f₁`-equal and `f₂`-equal
values, when `g` maps such arguments to `f`-equal results. -/
theorem _root_.Option.map_bind_bind {α β γ δ ε φ : Type} {f₁ : α → δ} {f₂ : β → ε} {f : γ → φ}
    {g : α → β → γ} {a a' : Option α} {c c' : Option β} (ha : a.map f₁ = a'.map f₁)
    (hc : c.map f₂ = c'.map f₂)
    (hg : ∀ {x x' y y'}, f₁ x = f₁ x' → f₂ y = f₂ y' → f (g x y) = f (g x' y')) :
    (do let x ← a; let y ← c; pure (g x y) : Option γ).map f =
      (do let x ← a'; let y ← c'; pure (g x y) : Option γ).map f := by
  match a, a', c, c', ha, hc with
  | none, none, _, _, _, _ => rfl
  | some _, some _, none, none, _, _ => rfl
  | some _, some _, some _, some _, ha, hc =>
    exact congrArg some (hg (Option.some.inj ha) (Option.some.inj hc))
  | none, some _, _, _, ha, _ | some _, none, _, _, ha, _ => nomatch ha
  | some _, some _, none, some _, _, hc | some _, some _, some _, none, _, hc => nomatch hc

/-- Two results related by `R`: one fault, or values related by `R`. -/
inductive _root_.Except.Rel {ε α β : Type} (R : α → β → Prop) : Except ε α → Except ε β → Prop
  /-- One fault on both sides. -/
  | error (e : ε) : Except.Rel R (.error e) (.error e)
  /-- Results related by `R`. -/
  | ok {a b} : R a b → Except.Rel R (.ok a) (.ok b)

/-- For every relation that relates each value to itself, every result is related to itself. -/
theorem _root_.Except.Rel.refl {ε α : Type} {R : α → α → Prop} (h : ∀ a, R a a) :
    ∀ x : Except ε α, Except.Rel R x x
  | .error e => .error e
  | .ok a => .ok (h a)

/-- Related results bound to functions that give related results on related values give related
results. -/
theorem _root_.Except.Rel.bind {ε α β γ δ : Type} {R : α → β → Prop} {S : γ → δ → Prop}
    {x₁ : Except ε α} {x₂ : Except ε β} (h : Except.Rel R x₁ x₂) {f₁ : α → Except ε γ}
    {f₂ : β → Except ε δ} (hf : ∀ a b, R a b → Except.Rel S (f₁ a) (f₂ b)) :
    Except.Rel S (x₁ >>= f₁) (x₂ >>= f₂) := by
  cases h with
  | error e => exact .error e
  | ok h => exact hf _ _ h

/-- Functions that relate related values, mapped over related results, give related results. -/
theorem _root_.Except.Rel.map {ε α β γ δ : Type} {R : α → β → Prop} {S : γ → δ → Prop}
    {x₁ : Except ε α} {x₂ : Except ε β} (h : Except.Rel R x₁ x₂) {f₁ : α → γ} {f₂ : β → δ}
    (hf : ∀ a b, R a b → S (f₁ a) (f₂ b)) : Except.Rel S (f₁ <$> x₁) (f₂ <$> x₂) := by
  cases h with
  | error e => exact .error e
  | ok h => exact .ok (hf _ _ h)

/-- For all functions that give related results on related values, and all lists related element
by element, `mapM` gives one fault (the first) or lists related element by element. -/
theorem _root_.Except.Rel.mapM {ε α β γ δ : Type} {R : α → β → Prop} {S : γ → δ → Prop}
    {f : α → Except ε γ} {g : β → Except ε δ} (hf : ∀ a b, R a b → Except.Rel S (f a) (g b)) :
    ∀ {xs : List α} {ys : List β}, List.Forall₂ R xs ys →
      Except.Rel (List.Forall₂ S) (xs.mapM f) (ys.mapM g)
  | [], [], .nil => .ok .nil
  | _ :: _, _ :: _, .cons h hs => by
    simp only [List.mapM_cons]
    exact (hf _ _ h).bind fun _ _ hc =>
      (Except.Rel.mapM hf hs).bind fun _ _ hcs => .ok (.cons hc hcs)

/-- For every list and all step functions that give related results on related accumulators at
each of its elements, `foldlM` from related accumulators gives one fault (the first) or related
results. -/
theorem _root_.Except.Rel.foldlM {ε α β γ : Type} {R : α → β → Prop} {f : α → γ → Except ε α}
    {g : β → γ → Except ε β} : ∀ {as : List γ},
    (∀ a ∈ as, ∀ x y, R x y → Except.Rel R (f x a) (g y a)) →
    ∀ {x y}, R x y → Except.Rel R (as.foldlM f x) (as.foldlM g y)
  | [], _, _, _, h => .ok h
  | a :: as, hf, _, _, h => by
    simp only [List.foldlM_cons]
    exact (hf a (by simp) _ _ h).bind fun _ _ h' =>
      Except.Rel.foldlM (fun b hb => hf b (by simp [hb])) h'

/-- For every relation, lists related element by element, numbered from one index, are related
element by element, at one index. -/
theorem _root_.List.Forall₂.zipIdx {α β : Type} {R : α → β → Prop} :
    ∀ {xs : List α} {ys : List β} (n : Nat), List.Forall₂ R xs ys →
      List.Forall₂ (fun p q => R p.1 q.1 ∧ p.2 = q.2) (xs.zipIdx n) (ys.zipIdx n)
  | [], [], _, .nil => .nil
  | _ :: _, _ :: _, n, .cons h hs => .cons ⟨h, rfl⟩ (List.Forall₂.zipIdx (n + 1) hs)

/-- For all relations, two pairs of lists related element by element zip to lists related
element by element. -/
theorem _root_.List.Forall₂.zip {α β γ δ : Type} {R : α → β → Prop} {S : γ → δ → Prop} :
    ∀ {xs : List α} {ys : List β} {us : List γ} {vs : List δ}, List.Forall₂ R xs ys →
      List.Forall₂ S us vs → List.Forall₂ (fun p q => R p.1 q.1 ∧ S p.2 q.2) (xs.zip us) (ys.zip vs)
  | [], [], _, _, .nil, _ => .nil
  | _ :: _, _ :: _, [], [], .cons _ _, .nil => .nil
  | _ :: _, _ :: _, _ :: _, _ :: _, .cons h hs, .cons h' hs' => .cons ⟨h, h'⟩ (hs.zip hs')

/-- For every relation, lists related element by element are related at every index: both
elements absent, or both present and related (`Option.Rel`). -/
theorem _root_.List.Forall₂.getElem? {α β : Type} {R : α → β → Prop} :
    ∀ {xs : List α} {ys : List β}, List.Forall₂ R xs ys → ∀ n : Nat, Option.Rel R xs[n]? ys[n]?
  | [], [], .nil, _ => .none
  | _ :: _, _ :: _, .cons h _, 0 => .some h
  | _ :: _, _ :: _, .cons _ hs, n + 1 => hs.getElem? n

/-- For every relation, lists related element by element, with related elements set at one index,
are related element by element. -/
theorem _root_.List.Forall₂.set {α β : Type} {R : α → β → Prop} {a : α} {b : β} (hab : R a b) :
    ∀ {xs : List α} {ys : List β}, List.Forall₂ R xs ys → ∀ n : Nat,
      List.Forall₂ R (xs.set n a) (ys.set n b)
  | [], [], .nil, _ => .nil
  | _ :: _, _ :: _, .cons _ hs, 0 => .cons hab hs
  | _ :: _, _ :: _, .cons h hs, n + 1 => .cons h (List.Forall₂.set hab hs n)

end MojoProof.Sem
