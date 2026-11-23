import MojoProof.Sym.Term
import MojoProof.Sem.Confluence

/-!
# A load after a store: the stored value or the frame

The value of a `load` after a `store` of the block (`SNode.loadAfter`, MojoProof/Sym/Term.lean),
the load from the memory its effects before it make (`SEff.run`), one effect at a time:

* `Mem.load_store_apart`: a load at a pointer apart from a store's bytes (another block, or byte
  ranges that do not overlap, of the load's and the store's sizes) gives after the store what it
  gives before it.
* `SNode.eval_loadAfter_nil`: with no effect before it, the node is the `load` from the entry
  memory (`SNode.load`).
* `SNode.eval_loadAfter_log`: a `load` effect (`SEff.load`, which only logs) leaves the node's
  value as it is.
* `SNode.eval_loadAfter_store`: after a `store` of a value of the load's type at a pointer of the
  same value, through the same address space and with the same alignment, the node is the value
  the stored bytes decode to (`Mem.load_store`).
* `SNode.eval_loadAfter_apart`: after a `store` whose bytes are apart from the load's, the node's
  value is what it is without the `store` (`Mem.load_store_apart`).

With the four node lemmas a node's value after effects whose pointers are known to be equal or
apart is a value of the entry memory or a stored value. For every valuation, node values,
statements and effects; when the pointers are neither (the checker's terms say nothing of how two
entry registers' pointers lie), no lemma applies and the node stays the `load` from the memory the
effects make.
-/

namespace MojoProof.Sem

open MojoProof.LLVM

/-- **A load apart from a store**: for every layout, memory, two threads, address spaces, types
and alignments, after a store of type `t` at `p` that succeeds, a load of type `t'` at `p'` that
succeeds before it, whose bytes are apart from the store's (`p'` in another block, or its
`l.stored t'` bytes from `p'.off` before or after the `l.stored t` bytes from `p.off`), gives the
same value. -/
theorem Mem.load_store_apart {l : Layout} {m m' : Mem} {w w' : Who} {a a' : Nat} {t t' : Ty}
    {v v' : Val} {p p' : Ptr} {al al' : Option Nat} {op : Option RmwOp}
    (h : m.store l w a t v p al op = .ok m')
    (hap : p'.block ≠ p.block ∨ p'.off.toNat + l.stored t' ≤ p.off.toNat ∨
      p.off.toNat + l.stored t ≤ p'.off.toNat)
    (hv : m.load l w' a' t' p' al' = .ok v') : m'.load l w' a' t' p' al' = .ok v' := by
  obtain ⟨blk, bs, hc, -, hbs, rfl⟩ := Mem.store_inv h
  obtain ⟨blk', hc', hd⟩ := Mem.load_inv hv
  have hlen := l.encode_length _ _ _ hbs
  by_cases hb : p'.block = p.block
  · obtain rfl : blk' = blk := by
      have h1 := (Mem.check_inv hc').1
      rw [hb, (Mem.check_inv hc).1] at h1
      exact (Option.some.inj h1).symm
    have hc'' := Mem.check_put (m := m) p.off.toNat bs hc'
    rw [hb] at hc''
    refine Mem.load_of_check ((Mem.check_log _ _).trans hc'') ?_
    rw [Block.read_put_apart _ _ (by rw [hlen]; omega)]
    exact hd
  · refine Mem.load_of_check (blk := blk') ((Mem.check_log _ _).trans ?_) hd
    rw [← hc']
    simp only [Mem.check, Mem.block, Mem.addr, Mem.set, hb, ↓reduceIte]

end MojoProof.Sem

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **With no effect before it**, a `load` node after the effects is the `load` from the entry
memory: for every valuation, node values, statement and pointer term. -/
theorem SNode.eval_loadAfter_nil {V : Valuation} {vs : List (Except Fault Val)} {lbl pc : Nat}
    {p : SVal} : (SNode.loadAfter lbl pc p []).eval V vs = (SNode.load lbl pc p).eval V vs := by
  rfl

/-- **A `load` effect leaves the node as it is**: for every valuation, node values, statement,
pointer term and effects `es`, if `es` and then the `load` effect of statement `pc'` of block
`lbl'` through `y` run, the node after them has the value of the node after `es`: a `load`
effect only logs the access, and a load reads no log. -/
theorem SNode.eval_loadAfter_log {V : Valuation} {vs : List (Except Fault Val)}
    {lbl pc lbl' pc' : Nat} {p y : SVal} {es : List SEff} {m : Mem}
    (hr : SEff.run V vs (es ++ [.load lbl' pc' y]) = .ok m) :
    (SNode.loadAfter lbl pc p (es ++ [.load lbl' pc' y])).eval V vs =
      (SNode.loadAfter lbl pc p es).eval V vs := by
  obtain ⟨m₀, hm, he⟩ := SEff.run_snoc hr
  have hlog : ∃ e, m = m₀.log e := by
    simp only [SEff.apply] at he
    split at he
    · obtain ⟨pv, -, he⟩ := Except.bind_eq_ok.1 he
      obtain ⟨q, -, he⟩ := Except.bind_eq_ok.1 he
      exact ⟨_, (Except.ok.inj he).symm⟩
    · cases he
  obtain ⟨e, rfl⟩ := hlog
  simp only [SNode.eval]
  rw [hr, hm]
  rfl

/-- **A `load` after a `store` at the same pointer is the stored value**: for every valuation
`V`, node values `vs`, effects `es`, and statements, the `load` at position `pc` of block `lbl`
of type `t` through a pointer of space `a` and the `store` at position `pc'` of block `lbl'` of a
value of type `t` through a pointer of the same space, with the same alignment (`al` and `al'`,
each `t`'s by default): if `es` and then the `store` of `x` at `y` run, `y` has the value of the
load's pointer term `p`, `x` has value `v`, which encodes to bytes `bs` that decode to `v'`, and
`v'` is defined or the load is not `noundef`, then the node after them is `v'`. -/
theorem SNode.eval_loadAfter_store {V : Valuation} {vs : List (Except Fault Val)}
    {lbl pc lbl' pc' a : Nat} {d d' : Option Nat} {vol vol' : Bool} {t : Ty} {o o' w : Value}
    {al al' : Option Nat} {md md' : List (String × Nat)} {p x y : SVal} {es : List SEff}
    {m : Mem} {v v' : Val} {bs : List MemByte}
    (hl : V.stmt lbl pc = some ⟨d, .load vol t (.mk (.ptr a) o) al, md⟩)
    (hs : V.stmt lbl' pc' = some ⟨d', .store vol' (.mk t w) (.mk (.ptr a) o') al', md'⟩)
    (hal : al'.getD (V.ctx.prog.layout.align t) = al.getD (V.ctx.prog.layout.align t))
    (hr : SEff.run V vs (es ++ [.store lbl' pc' x y]) = .ok m) (hy : y.eval V vs = p.eval V vs)
    (hx : x.eval V vs = .ok v) (hbs : V.ctx.prog.layout.encode t v = some bs)
    (hd : V.ctx.prog.layout.decode t bs = some v')
    (hu : (md.any (·.1 == "noundef") && !v'.defined) = false) :
    (SNode.loadAfter lbl pc p (es ++ [.store lbl' pc' x y])).eval V vs = .ok v' := by
  obtain ⟨m₀, -, he⟩ := SEff.run_snoc hr
  simp only [SEff.apply, hs] at he
  obtain ⟨xv, hxv, he⟩ := Except.bind_eq_ok.1 he
  rw [hx] at hxv
  cases hxv
  obtain ⟨pv, hpv, he⟩ := Except.bind_eq_ok.1 he
  obtain ⟨q, hq, he⟩ := Except.bind_eq_ok.1 he
  obtain ⟨_, _, hc, -⟩ := Mem.store_inv he
  rw [hal] at hc
  rw [hy] at hpv
  simp only [SNode.eval, hl]
  refine Except.bind_eq_ok.2 ⟨pv, hpv, Except.bind_eq_ok.2 ⟨q, hq, Except.bind_eq_ok.2 ⟨m, hr,
    Except.bind_eq_ok.2 ⟨v', Mem.load_store he hc hbs hd, ?_⟩⟩⟩⟩
  simp only [hu, Bool.cond_false, pure, Except.pure]

/-- **A `load` after a `store` apart from it is the value without the `store`**: for every
valuation `V`, node values `vs`, effects `es`, and statements, the `load` at position `pc` of
block `lbl` of type `t` and the `store` at position `pc'` of block `lbl'` of a value of type `t'`:
if `es` and then the `store` of `x` at `y` run, the load's pointer term `p` is the pointer `r`
and `y` the pointer `r'`, apart (`r` in another block than `r'`, or the `stored t` bytes from
`r.off` before or after the `stored t'` bytes from `r'.off`), and the node after `es` has value
`v`, then the node after `es` and the `store` has value `v`. -/
theorem SNode.eval_loadAfter_apart {V : Valuation} {vs : List (Except Fault Val)}
    {lbl pc lbl' pc' a a' : Nat} {d d' : Option Nat} {vol vol' : Bool} {t t' : Ty}
    {o o' w : Value} {al al' : Option Nat} {md md' : List (String × Nat)} {p x y : SVal}
    {es : List SEff} {m : Mem} {v : Val} {r r' : Ptr}
    (hl : V.stmt lbl pc = some ⟨d, .load vol t (.mk (.ptr a) o) al, md⟩)
    (hs : V.stmt lbl' pc' = some ⟨d', .store vol' (.mk t' w) (.mk (.ptr a') o') al', md'⟩)
    (hr : SEff.run V vs (es ++ [.store lbl' pc' x y]) = .ok m)
    (hp : p.eval V vs = .ok (.ptr r)) (hy : y.eval V vs = .ok (.ptr r'))
    (hap : r.block ≠ r'.block ∨ r.off.toNat + V.ctx.prog.layout.stored t ≤ r'.off.toNat ∨
      r'.off.toNat + V.ctx.prog.layout.stored t' ≤ r.off.toNat)
    (hv : (SNode.loadAfter lbl pc p es).eval V vs = .ok v) :
    (SNode.loadAfter lbl pc p (es ++ [.store lbl' pc' x y])).eval V vs = .ok v := by
  obtain ⟨m₀, hm, he⟩ := SEff.run_snoc hr
  simp only [SEff.apply, hs] at he
  obtain ⟨_, -, he⟩ := Except.bind_eq_ok.1 he
  obtain ⟨yv, hyv, he⟩ := Except.bind_eq_ok.1 he
  rw [hy] at hyv
  cases hyv
  obtain ⟨q', hq', he⟩ := Except.bind_eq_ok.1 he
  cases hq'
  simp only [SNode.eval, hl] at hv ⊢
  obtain ⟨pv, hpv, hv⟩ := Except.bind_eq_ok.1 hv
  rw [hp] at hpv
  cases hpv
  obtain ⟨q, hq, hv⟩ := Except.bind_eq_ok.1 hv
  cases hq
  obtain ⟨m₁, hm₁, hv⟩ := Except.bind_eq_ok.1 hv
  obtain rfl : m₁ = m₀ := Except.ok.inj (hm₁.symm.trans hm)
  obtain ⟨v₀, hv₀, hv⟩ := Except.bind_eq_ok.1 hv
  exact Except.bind_eq_ok.2 ⟨.ptr r, hp, Except.bind_eq_ok.2 ⟨r, rfl, Except.bind_eq_ok.2 ⟨m, hr,
    Except.bind_eq_ok.2 ⟨v₀, Mem.load_store_apart he hap hv₀, hv⟩⟩⟩⟩

end MojoProof.Sym
