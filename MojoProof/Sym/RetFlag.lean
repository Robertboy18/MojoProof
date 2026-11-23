import MojoProof.Sym.Path

/-!
# A path with no `fmul contract` product is a `RetWith true` when it is a `Ret`

docs/proofs/kernel.md. The flag `contract` changes one thing about a path's valuations: the
`fmul contract` operands each block leaves (`prodsWith`), which are those the block's register
entries give (`regProdIn`) with the flag and none for a register the block sets (`regProd`)
without it. A summary whose register entries name no `fmul contract` product
(`Summary.noProds`: `SVal.factors` is `none` for each) leaves the same operands either way, so
on a path of such summaries (`pathNoProds`) every valuation `Valuation.intoWith` gives is the
same with or without the flag, and so are `WalkWith`, `Valuation.lastWith` and `RetWith`.

* `RetWith.true_eq`: on such a path, `RetWith true V Q ps = RetWith false V Q ps`, for every
  valuation and predicate.
* `RetWith.exists_true_of_ret`: on a list of such paths, some path is a `RetWith true` when some
  path is a `Ret`; the `map2` clause of `mojo_kernel` with the flag `contract`
  (Sym/KernelCmd.lean) moves its `mojo_ret` proof of `n.ret` by it.

Both checks are `Bool`s, decided on a concrete path. Every result is for every program: the
summaries are the only premise.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- Whether summary `S` records no `fmul contract` product: for each register entry of `S`,
`SVal.factors` over `S`'s node table is `none`. -/
def Summary.noProds (S : Summary) : Bool :=
  S.regs.all fun e => (e.2.factors S.nodes).isNone

/-- Whether no summary of the path `ps` records an `fmul contract` product
(`Summary.noProds`). -/
def pathNoProds (ps : List (Nat × List Cond × Summary)) : Bool :=
  ps.all fun b => b.2.2.noProds

/-- A property of every value of a list of pairs holds of the value `List.lookup` finds: for
every predicate `p`, list `l` of numbered values each of which meets `p`, number `r` and value
`x` that `l.lookup r` gives, `p x` holds. -/
theorem lookup_all {α : Type} {p : α → Bool} :
    ∀ {l : List (Nat × α)} {r : Nat} {x : α}, l.all (fun e => p e.2) = true →
      l.lookup r = some x → p x = true
  | [], _, _, _, hx => by cases hx
  | (s, v) :: l, r, x, h, hx => by
    rw [List.all_cons, Bool.and_eq_true] at h
    by_cases e : r = s
    · subst e
      simp only [List.lookup, beq_self_eq_true, Option.some.injEq] at hx
      exact hx ▸ h.1
    · rw [lookup_ne e] at hx
      exact lookup_all h.2 hx

/-- **A summary with no `fmul contract` product leaves the same operands with or without the
flag**: for every summary `S` with `Summary.noProds` and valuation `V`,
`prodsWith true V S = prodsWith false V S`. -/
theorem prodsWith_noProds {S : Summary} (h : S.noProds = true) (V : Valuation) :
    prodsWith true V S = prodsWith false V S := by
  funext r
  simp only [prodsWith, Bool.cond_true, Bool.cond_false, regProdIn, regProd]
  cases hl : S.regs.lookup r with
  | none => rfl
  | some x =>
    have hx := Option.isNone_iff_eq_none.1
      (lookup_all (p := fun x : SVal => (x.factors S.nodes).isNone) h hl)
    simp only [hx, Option.bind_none]

/-- `Valuation.afterWith` is the same with or without the flag after a summary with no
`fmul contract` product (`prodsWith_noProds`), for every valuation. -/
theorem Valuation.afterWith_noProds {S : Summary} (h : S.noProds = true) (V : Valuation) :
    V.afterWith true S = V.afterWith false S := by
  unfold Valuation.afterWith
  rw [prodsWith_noProds h]

/-- `Valuation.intoWith` is the same with or without the flag after a summary with no
`fmul contract` product (`Valuation.afterWith_noProds`), for every valuation and label. -/
theorem Valuation.intoWith_noProds {S : Summary} (h : S.noProds = true) (V : Valuation)
    (l : Nat) : V.intoWith true l S = V.intoWith false l S := by
  unfold Valuation.intoWith Valuation.frameAtWith
  rw [Valuation.afterWith_noProds h]

/-- `WalkWith` is the same with or without the flag on a path with no `fmul contract` product
(`pathNoProds`), for every valuation. -/
theorem walkWith_noProds : ∀ {V : Valuation} {ps : List (Nat × List Cond × Summary)},
    pathNoProds ps = true → WalkWith true V ps = WalkWith false V ps
  | _, [], _ => rfl
  | _, [(_, _, _)], _ => rfl
  | V, (l, ds, S) :: (l', ds', S') :: ps, h => by
    rw [pathNoProds, List.all_cons, Bool.and_eq_true] at h
    simp only [WalkWith]
    rw [Valuation.intoWith_noProds h.1, walkWith_noProds (ps := (l', ds', S') :: ps) h.2]

/-- `Valuation.lastWith` is the same with or without the flag from a block `S` and a rest `ps`
with no `fmul contract` product, for every valuation and label. -/
theorem Valuation.lastWith_noProds : ∀ {V : Valuation} {l : Nat} {S : Summary}
    {ps : List (Nat × List Cond × Summary)}, S.noProds = true → pathNoProds ps = true →
      V.lastWith true l S ps = V.lastWith false l S ps
  | _, _, _, [], _, _ => rfl
  | V, l, S, (l', ds', S') :: ps, hS, h => by
    rw [pathNoProds, List.all_cons, Bool.and_eq_true] at h
    simp only [Valuation.lastWith]
    rw [Valuation.intoWith_noProds hS, Valuation.lastWith_noProds (ps := ps) h.1 h.2]

/-- **The flag does not change `RetWith` on a path with no `fmul contract` product**: for every
valuation `V`, predicate `Q` and path `ps` with `pathNoProds`,
`RetWith true V Q ps = RetWith false V Q ps` (`walkWith_noProds`,
`Valuation.lastWith_noProds`). -/
theorem RetWith.true_eq {V : Valuation} {Q : Mem → Prop} :
    ∀ {ps : List (Nat × List Cond × Summary)}, pathNoProds ps = true →
      RetWith true V Q ps = RetWith false V Q ps
  | [], _ => rfl
  | (l, ds, S) :: ps, h => by
    have h' := h
    rw [pathNoProds, List.all_cons, Bool.and_eq_true] at h'
    simp only [RetWith]
    rw [walkWith_noProds h, Valuation.lastWith_noProds (ps := ps) h'.1 h'.2]

set_option smartUnfolding false in
/-- **Some path is a `RetWith true` when some path is a `Ret`, on paths with no `fmul contract`
product**: for every valuation `V`, predicate `Q` and list `paths` of paths each with
`pathNoProds` (decided on `paths`), a path of `paths` that is a `Ret` from `V` to `Q` is a
`RetWith true` (`RetWith.true_eq`; `RetWith false` and `Ret` agree definitionally with
`smartUnfolding` off). -/
theorem RetWith.exists_true_of_ret {V : Valuation} {Q : Mem → Prop}
    {paths : List (List (Nat × List Cond × Summary))} (hp : paths.all pathNoProds = true)
    (h : ∃ ps ∈ paths, Ret V Q ps) : ∃ ps ∈ paths, RetWith true V Q ps := by
  obtain ⟨ps, hm, hR⟩ := h
  refine ⟨ps, hm, ?_⟩
  rw [RetWith.true_eq (List.all_eq_true.1 hp ps hm)]
  exact hR

end MojoProof.Sym
