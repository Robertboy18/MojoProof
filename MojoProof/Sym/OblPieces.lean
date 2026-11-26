import MojoProof.Sym.OblLemmas

/-!
# Loads of a stored aggregate's elements, `i32` slots, and vector inserts

The facts a frame's run lemma needs when a block stores an aggregate of pointers whole into an
`alloca` slot and loads its elements back (gemv_kernel's `%6`: `store [2 x ptr] %27, ptr %7`,
then `%29 = load ptr, ptr %28` and `%33 = load ptr, ptr %32`), loads `i32` slots through the
loaded pointers after lifetime markers of other blocks (`%30`, `%34`), and builds a vector of
the loaded words (`%31`, `%35`).

* `Block.read_put_slice`: the bytes read inside a put are a slice of the put's bytes.
* `Mem.load_store_elem`: a load of element `k` of an array stored whole gives element `k` (as
  `Mem.load_store` gives a whole value).
* `Mem.load_store_codec_of_block`: `Mem.load_store_codec` on a later memory with the same block.
* `SNode.eval_loadAfter_elem`: `SNode.loadAfter`'s node for a load of an element of an array the
  last effect stored whole.
* `SNode.eval_insEltAt_at`, `SNode.eval_constAt_undef`: `insertelement`'s node and an `undef`
  operand's node.
* `Mem.alloc_num_ne`: an allocation at block number `x` keeps every other block.

MojoProofTest/GemvEntry.lean instantiates each at gemv_kernel's statements.
-/

namespace MojoProof.Sem
open MojoProof.LLVM

/-- For every block, offset, byte list and range `j, n` inside it, reading `n` bytes at `o + j`
after putting the bytes at `o` gives the `n` put bytes from `j` (`Layout.slice bs j n`). -/
theorem Block.read_put_slice (blk : Block) (o : Nat) (bs : List MemByte) {j n : Nat}
    (h : j + n ≤ bs.length) : (blk.put o bs).read (o + j) n = (bs.drop j).take n := by
  apply List.ext_getElem (by simp [Block.read]; omega)
  intro i h1 _
  simp only [Block.read, List.length_map, List.length_range] at h1
  simp only [Block.read, Block.put, List.getElem_map, List.getElem_range,
    List.getElem_take, List.getElem_drop]
  rw [ite_eq_left (by omega), List.getD_eq_getElem?_getD,
    List.getElem?_eq_getElem (by omega)]
  simp only [Option.getD_some]
  congr 1
  omega

/-- **The element lemma.** For every layout, memories, threads, address space, codec `enc` of
type `t` (`Layout.Codec`: integers, floats, pointers), list `xs` and index `k < xs.length`: after
a store of the array `[xs.length x t]` of `xs`'s encodings at `p`, a load of `t` at a pointer `q`
in `p`'s block at `k` elements past `p`, whose check succeeds before the store, gives
`enc xs[k]`. `Mem.load_store` is the case of the whole value. -/
theorem Mem.load_store_elem {l : Layout} {m m' : Mem} {w w' : Who} {a : Nat} {t : Ty}
    {α : Type} {enc : α → Val} {xs : List α} {k : Nat} {p q : Ptr} {al al' : Option Nat}
    {op : Option RmwOp} {r : Sem.Block × Nat} (hc : l.Codec t enc) (hk : k < xs.length)
    (h : m.store l w a (.arr xs.length t) (.agg (xs.map enc)) p al op = .ok m')
    (hb : q.block = p.block) (ho : q.off = p.off + ((k * l.size t : Nat) : Int))
    (hq : m.check l w' a q (l.stored t) al' = .ok r) :
    m'.load l w' a t q al' = .ok (enc xs[k]) := by
  obtain ⟨blk, bs, hc', -, hbs, rfl⟩ := Mem.store_inv h
  obtain ⟨out, hout, hlen, hdec⟩ := Layout.encodeAll_spec hc (l.stored_le_size t) xs
  have hbs' : bs = out := by
    simp only [Layout.encode, List.length_map, ↓reduceIte, hout] at hbs
    exact (Option.some.inj hbs).symm
  subst hbs'
  obtain ⟨blk', o⟩ := r
  obtain ⟨hb', -, -, -, -, -, -, rfl⟩ := Mem.check_inv hq
  obtain ⟨hb'', -, -, ⟨hp0, -⟩, -, -, -, -⟩ := Mem.check_inv hc'
  obtain rfl : blk' = blk := by
    rw [hb, hb''] at hb'
    exact (Option.some.inj hb').symm
  have hc'' := Mem.check_put (m := m) p.off.toNat bs hq
  rw [hb] at hc''
  refine Mem.load_of_check ((Mem.check_log _ _).trans hc'') ?_
  generalize hs : k * l.size t = s at ho
  have e : q.off.toNat = p.off.toNat + s := by omega
  have h1 : (k + 1) * l.size t ≤ xs.length * l.size t := Nat.mul_le_mul_right _ hk
  rw [Nat.succ_mul, hs] at h1
  have h2 := l.stored_le_size t
  rw [e, Block.read_put_slice _ _ _ (by rw [hlen]; omega), ← hs]
  exact hdec k hk

/-- **A slot through later changes of other blocks.** For every layout, memories, threads,
address space, codec `enc` of type `t` and value `x`: after a store of `enc x` at `p` whose check
succeeds before the store, a load at `p` on every later memory `m''` with the same block at
`p.block` gives `enc x` (`Mem.load_store_codec`, `Mem.load_of_block`). The later memories of a run
whose lifetime markers and stores touch other blocks are such memories
(`Mem.foldl_setLive_blocks`, `Mem.store_blocks`). -/
theorem Mem.load_store_codec_of_block {l : Layout} {m m' m'' : Mem} {w w' : Who} {a : Nat}
    {t : Ty} {p : Ptr} {al al' : Option Nat} {op : Option RmwOp} {r : Block × Nat} {α : Type}
    {enc : α → Val} (he : l.Codec t enc) (x : α) (h : m.store l w a t (enc x) p al op = .ok m')
    (hc : m.check l w' a p (l.stored t) al' = .ok r)
    (hb : m''.blocks p.block = m'.blocks p.block) : m''.load l w' a t p al' = .ok (enc x) :=
  (MojoProof.Sym.Mem.load_of_block hb w' a t al').trans (Mem.load_store_codec he x h hc)

/-- **An allocation keeps the other blocks**: for every layout `l`, memory `m`, space, size,
alignment, liveness, writability, owner, addresses, initial bytes and block numbers `x`, `b` with
`b ≠ x`, `Mem.alloc` at number `x` leaves block `b` of `m` as it was (the `alloca` slots `%6`
allocates keep the buffers and each other). -/
theorem Mem.alloc_num_ne (l : Layout) (m : Mem) (space size align : Nat) (live readOnly : Bool)
    (owner : Owner) (addr gaddr : Nat) (init : List MemByte) {x b : Nat} (h : b ≠ x) :
    (m.alloc l space size align live readOnly owner addr gaddr init (some x)).1.blocks b =
      m.blocks b := by
  simp [Mem.alloc, Mem.set, h]

end MojoProof.Sem

namespace MojoProof.Sym
open MojoProof.LLVM MojoProof.Sem

/-- **`loadAfter` at an element of an array stored whole.** For every program, function,
valuation (so every launch, context, thread and memory) and node list: if the effects end in a
`store` of the array `[n x t]` of `xs`'s encodings (`enc` a codec of `t`, `xs.length = n`) at
`r`, the effects run, and the node's `load` of `t` reads at a pointer `q` in `r`'s block at `k`
elements past `r` whose check succeeds on the memory before the store, the node evaluates to
`enc xs[k]` (`Mem.load_store_elem`). -/
theorem SNode.eval_loadAfter_elem {V : Valuation} {vs : List (Except Fault Val)}
    {P : Program} {F : Func} {lbl pc lbl' pc' a k n : Nat} {d d' : Option Nat}
    {vol vol' : Bool} {t : Ty} {o o' w : Value} {al al' : Option Nat}
    {md md' : List (String × Nat)} {p x y : SVal} {es : List SEff} {α : Type} {enc : α → Val}
    {xs : List α} {q r : Ptr} {M₀ : Mem} {rr : Sem.Block × Nat}
    (hF : V.fn = F) (hP : V.ctx.prog = P) (hc : P.layout.Codec t enc) (hn : xs.length = n)
    (hk : k < n)
    (hl : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨d, .load vol t (.mk (.ptr a) o) al, md⟩)
    (hs : (F.blocks.find? (·.label == lbl')).bind (·.stmts[pc']?) =
      some ⟨d', .store vol' (.mk (.arr n t) w) (.mk (.ptr a) o') al', md'⟩)
    (hr : ∃ m, SEff.run V vs (es ++ [.store lbl' pc' x y]) = .ok m)
    (hx : x.eval V vs = .ok (.agg (xs.map enc))) (hy : y.eval V vs = .ok (.ptr r))
    (hp : p.eval V vs = .ok (.ptr q)) (hb : q.block = r.block)
    (ho : q.off = r.off + ((k * P.layout.size t : Nat) : Int))
    (hm : SEff.run V vs es = .ok M₀)
    (hq : M₀.check P.layout V.ctx.who a q (P.layout.stored t)
      (some (al.getD (P.layout.align t))) = .ok rr) :
    (SNode.loadAfter lbl pc p (es ++ [.store lbl' pc' x y])).eval V vs =
      .ok (enc (xs[k]'(hn ▸ hk))) := by
  subst hP hn
  obtain ⟨m, hm'⟩ := hr
  obtain ⟨m₀, hm₀, he⟩ := SEff.run_snoc hm'
  obtain rfl : m₀ = M₀ := Except.ok.inj (hm₀.symm.trans hm)
  simp only [SEff.apply, Valuation.stmt_of_fn hF hs] at he
  obtain ⟨xv, hxv, he⟩ := Except.bind_eq_ok.1 he
  rw [hx] at hxv
  cases hxv
  obtain ⟨pv, hpv, he⟩ := Except.bind_eq_ok.1 he
  rw [hy] at hpv
  cases hpv
  obtain ⟨q', hq', he⟩ := Except.bind_eq_ok.1 he
  cases hq'
  have hu : (md.any (·.1 == "noundef") && !(enc xs[k]).defined) = false := by
    rw [hc.defined, Bool.not_true, Bool.and_false]
  simp only [SNode.eval, Valuation.stmt_of_fn hF hl]
  refine Except.bind_eq_ok.2 ⟨.ptr q, hp, Except.bind_eq_ok.2 ⟨q, rfl, Except.bind_eq_ok.2 ⟨m, hm',
    Except.bind_eq_ok.2 ⟨enc xs[k], Mem.load_store_elem hc hk he hb ho hq, ?_⟩⟩⟩⟩
  simp only [hu, Bool.cond_false, pure, Except.pure]

/-- **`insertelement`'s node.** For every function, valuation (so every program, launch,
context, thread and memory) and node list: the node of an `insertelement` statement evaluates to
every value `w` that `insertE` gives at its operands' values. -/
theorem SNode.eval_insEltAt_at {V : Valuation} {vs : List (Except Fault Val)} {F : Func}
    {lbl pc : Nat} {a e i : SVal} {dst : Option Nat} {t : Ty} {x : Value} {y z : TValue}
    {md : List (String × Nat)} {va ve vi : Val} (hF : V.fn = F)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .insertelement (.mk t x) y z, md⟩)
    (ha : a.eval V vs = .ok va) (he : e.eval V vs = .ok ve) (hi : i.eval V vs = .ok vi) {w : Val}
    (hw : insertE t va ve vi = .ok w) : (SNode.insEltAt lbl pc a e i).eval V vs = .ok w := by
  have h : (SNode.insEltAt lbl pc a e i).eval V vs = insertE t va ve vi := by
    simp only [SNode.eval, SNode.evalMore, Valuation.stmt_of_fn hF hs, ha, he, hi]
    rfl
  exact h.trans hw

/-- **An `undef` operand's node.** For every function, valuation (so every program, launch,
context, thread and memory) and node list: the node of operand `i` of a statement, when that
operand is `undef` of type `t`, evaluates to `undef` filled at `t`. -/
theorem SNode.eval_constAt_undef {V : Valuation} {vs : List (Except Fault Val)} {F : Func}
    {lbl pc i : Nat} {st : Stmt} {t : Ty} (hF : V.fn = F)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) = some st)
    (ho : st.inst.operands[i]? = some (.mk t .undef)) :
    (SNode.constAt lbl pc i).eval V vs = .ok (fill .undef t) := by
  simp only [SNode.eval, SNode.evalMore, Valuation.stmt_of_fn hF hs, ho]
  rfl

end MojoProof.Sym
