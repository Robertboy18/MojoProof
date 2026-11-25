import GPUProof.OneRun

/-!
# Confluence along a surjection

For every pair of types, relations and sets, and every surjection `f` between the types that
maps the steps, the equivalence and the bad set of the first onto those of the second:
`Confluent` moves from the first to the second (`Confluent.transfer`). The identity is one such
map, for one relation, one equivalence and two bad sets with the same members; so is an
equivalence of types, and so is the map from a machine's states reachable from a start onto the
states of another machine reachable from the image of the start, when the second's steps are the
images of the first's.
-/

namespace GPUProof

/-- **Confluence moves along a surjection**, for every pair of types `α`, `β`, relations `r`, `e`
and set `B` on `α`, relations `r'`, `e'` and set `B'` on `β`, and every surjective `f : α → β`
with `r' (f a) (f b) ↔ r a b`, `e' (f a) (f b) ↔ e a b` and `B' (f a) ↔ B a`: if `r` is
`Confluent` up to `e` with `B` persistent, then `r'` is up to `e'` with `B'`. -/
theorem Confluent.transfer {α β : Type*} {r e : α → α → Prop} {B : α → Prop}
    {r' e' : β → β → Prop} {B' : β → Prop} {f : α → β} (hf : Function.Surjective f)
    (hr : ∀ a b, r' (f a) (f b) ↔ r a b) (he : ∀ a b, e' (f a) (f b) ↔ e a b)
    (hB : ∀ a, B' (f a) ↔ B a) (h : Confluent r e B) : Confluent r' e' B' where
  refl x := by
    obtain ⟨a, rfl⟩ := hf x
    exact (he a a).2 (h.refl a)
  symm {x y} := by
    obtain ⟨a, rfl⟩ := hf x
    obtain ⟨b, rfl⟩ := hf y
    rw [he, he]
    exact h.symm
  trans {x y z} := by
    obtain ⟨a, rfl⟩ := hf x
    obtain ⟨b, rfl⟩ := hf y
    obtain ⟨c, rfl⟩ := hf z
    rw [he, he, he]
    exact h.trans
  bisim {x x' y} := by
    obtain ⟨a, rfl⟩ := hf x
    obtain ⟨a', rfl⟩ := hf x'
    obtain ⟨b, rfl⟩ := hf y
    rw [he, hr]
    intro h1 h2
    obtain ⟨b', hb, hb'⟩ := h.bisim h1 h2
    exact ⟨f b', (hr _ _).2 hb, (he _ _).2 hb'⟩
  bad_eqv {x x'} := by
    obtain ⟨a, rfl⟩ := hf x
    obtain ⟨a', rfl⟩ := hf x'
    rw [he, hB, hB]
    exact h.bad_eqv
  bad_step {x y} := by
    obtain ⟨a, rfl⟩ := hf x
    obtain ⟨b, rfl⟩ := hf y
    rw [hB, hB, hr]
    exact h.bad_step
  diamond {x y z} := by
    obtain ⟨a, rfl⟩ := hf x
    obtain ⟨b, rfl⟩ := hf y
    obtain ⟨c, rfl⟩ := hf z
    rw [hr, hr, he, hB, hB]
    intro h1 h2
    rcases h.diamond h1 h2 with h3 | h3 | ⟨d, d', h3, h4, h5⟩
    · exact .inl h3
    · exact .inr (.inl h3)
    · refine .inr (.inr ⟨f d, f d', (hr _ _).2 h3, (hr _ _).2 h4, ?_⟩)
      rwa [he, hB, hB]

end GPUProof
