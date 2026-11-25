import MojoProof.Sym.Term
import MojoProof.Sem.SigDef

/-!
# A block's memory obligation checked on metadata

A block summary's `mem` obligation (`Cond.mem es`) says that its memory effects `es` run without a
fault (`SEff.run`). Each effect's faults depend on the metadata of the blocks (`sig.metaAt`: space,
size, liveness, read-only flag, owner, addresses), on its operand terms and on the entry memory's
`next`, never on bytes: a `store` writes bytes and keeps every block's metadata, a `load` only logs
its access, and an `alloca` adds one block. This module runs the effects on metadata alone:

* `Metas`: the metadata of the blocks by number; `Metas.write` is the checks of `Mem.write` read
  from metadata, with addresses by `Mem.addr` on `Metas.mem`, the memory of that metadata and
  poison bytes.
* `SEff.applyMeta`, `SEff.runMeta`: an effect, and the effects in order from the entry memory's
  metadata, on metadata, writing no byte.
* `MetaAgree m M`: memory `m` has metadata `M`. `MetaAgree.apply`: an effect that succeeds on `M`
  succeeds on every memory with that metadata, and the results agree; `MetaAgree.foldlM` the same
  for a list of effects, by induction on it. `MetaAgree.write_ok`, `MetaAgree.apply_ok` and
  `MetaAgree.foldlM_ok`: the converses (what succeeds on the memory succeeds on its metadata).
* `SEff.holds_iff_runMeta`: the obligation `Cond.mem es` holds exactly when the effects run on the
  entry memory's metadata, for every valuation, table of node values and list of effects, with no
  premise: the check is sound and complete.

MojoProofTest/MetaRun.lean checks it at one block of one program (vector_addition) at one launch,
and a mutant it refuses.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The metadata of the blocks of a memory, by block number (`sig.metaAt` of its blocks). -/
abbrev Metas := Nat → Option BlockMeta

namespace Metas

/-- The memory whose blocks have metadata `M` and only poison bytes, for every metadata: the
memory on which `Metas.write` computes addresses with `Mem.addr`. -/
def mem (M : Metas) : Mem :=
  { blocks := fun b => (M b).map fun k =>
      ⟨k.space, k.size, k.live, k.readOnly, k.owner, fun _ => .poison, k.addr, k.gaddr⟩ }

/-- The checks of `Mem.write` of `n` bytes read from metadata `M`, for every layout, thread, space,
pointer and alignment: the block exists, is live, admits `w`, holds the bytes, its address in
space `a` is aligned, and it is not read-only. -/
def write (l : Layout) (M : Metas) (w : Who) (a : Nat) (p : Ptr) (n : Nat)
    (align : Option Nat) : Except Fault Unit := do
  let some b := M p.block | throw (.ub "access to no block")
  unless b.live do throw (.ub "access to a dead block")
  unless b.owner.admits w do throw (.ub "access to another thread's or block's memory")
  unless 0 ≤ p.off ∧ p.off + n ≤ b.size do throw (.ub "access out of bounds")
  let ad ← M.mem.addr l a p
  if let some al := align then
    unless ad % al = 0 do throw (.ub "misaligned access")
  if b.readOnly then throw (.ub "store to read-only memory")

end Metas

/-- Memory `m` has metadata `M`: `sig.metaAt` of its blocks is `M` at every block number. -/
def MetaAgree (m : Mem) (M : Metas) : Prop := ∀ b, sig.metaAt m.blocks b = M b

/-- On memory `m` with metadata `M`, `Mem.addr` gives what it gives on `Metas.mem M`, for every
layout, space and pointer: it reads only the space and addresses of the pointer's block. -/
theorem MetaAgree.addr {m : Mem} {M : Metas} (h : MetaAgree m M) (l : Layout) (a : Nat) (p : Ptr) :
    m.addr l a p = M.mem.addr l a p := by
  have hb := h p.block
  simp only [sig] at hb
  unfold Mem.addr Metas.mem Mem.block
  simp only [← hb]
  cases m.blocks p.block <;> rfl

/-- Setting block `b` of memory `m` with metadata `M` to a block with the metadata of the one
there keeps the metadata `M`, for every memory and block. -/
theorem MetaAgree.set {m : Mem} {M : Metas} (h : MetaAgree m M) {b : Nat} {k k' : Sem.Block}
    (hk : m.blocks b = some k) (he : k'.meta = k.meta) : MetaAgree (m.set b k') M := by
  intro c
  have := h c
  simp only [sig, Mem.set] at this ⊢
  split
  · subst c; rw [← this, hk]; simp [he]
  · exact this

/-- On memory `m` with metadata `M`, a write of bytes `bs` whose checks pass on `M`
(`Metas.write`) succeeds, and the memory it leaves has metadata `M`, for every memory and write. -/
theorem MetaAgree.write {m : Mem} {M : Metas} (h : MetaAgree m M) {l : Layout} {w : Who} {a : Nat}
    {p : Ptr} {bs : List MemByte} {al : Option Nat}
    (hw : M.write l w a p bs.length al = .ok ()) :
    ∃ m', m.write l w a p bs al = .ok m' ∧ MetaAgree m' M := by
  have hb := h p.block
  simp only [sig] at hb
  unfold Metas.write at hw
  unfold Mem.write Mem.check
  simp only [Mem.block]
  rw [h.addr]
  cases hm : m.blocks p.block with
  | none => rw [hm] at hb; rw [← hb] at hw; cases hw
  | some k =>
    rw [hm] at hb; rw [← hb] at hw
    simp only [Option.map_some, Block.meta] at hw
    cases ha : M.mem.addr l a p with
    | error e =>
      by_cases h1 : k.live <;> by_cases h2 : k.owner.admits w <;>
        by_cases h3 : (0 ≤ p.off ∧ p.off + (bs.length : Int) ≤ k.size) <;>
        simp [h1, h2, h3, ha, bind, Except.bind, throw, throwThe, MonadExceptOf.throw] at hw
    | ok ad =>
      by_cases h1 : k.live <;> by_cases h2 : k.owner.admits w <;>
        by_cases h3 : (0 ≤ p.off ∧ p.off + (bs.length : Int) ≤ k.size) <;>
        by_cases h4 : k.readOnly <;> rcases al with _ | al <;>
        simp [h1, h2, h3, h4, ha, bind, Except.bind, throw, throwThe, MonadExceptOf.throw, pure,
          Except.pure] at hw ⊢
      all_goals first
        | exact h.set hm rfl
        | (split_ifs at hw ⊢; done)
        | (split_ifs at hw ⊢
           exact ⟨m.set p.block (k.put p.off.toNat bs), by simp [h4], h.set hm rfl⟩)

/-- Effect `e` on metadata `M`, under valuation `V` with node values `vs`, for every effect: a
`load` evaluates its pointer, a `store` its value and pointer, encodes the value and runs
`Metas.write`, and an `alloca` evaluates its count and adds the metadata of the block that
`SEff.apply` makes, refusing a number that has metadata; the faults are `SEff.apply`'s. -/
def SEff.applyMeta (V : Valuation) (vs : List (Except Fault Val)) (M : Metas) :
    SEff → Except Fault Metas
  | .load lbl pc p => match V.stmt lbl pc with
    | some ⟨_, .load _ _ (.mk (.ptr _) _) _, _⟩ => do
      let _ ← (← p.eval V vs).addr?
      pure M
    | _ => throw (.unsupported "symbolic load at no load")
  | .store lbl pc v p => match V.stmt lbl pc with
    | some ⟨_, .store _ (.mk t _) (.mk (.ptr a) _) al, _⟩ => do
      let x ← v.eval V vs
      let q ← (← p.eval V vs).addr?
      let some bs := V.ctx.prog.layout.encode t x
        | throw (.unsupported "store of a value not of the type")
      M.write V.ctx.prog.layout V.ctx.who a q bs.length
        (some (al.getD (V.ctx.prog.layout.align t)))
      pure M
    | _ => throw (.unsupported "symbolic store at no store")
  | .alloca lbl pc n cnt => match V.stmt lbl pc with
    | some ⟨res, .alloca t _ al, _⟩ => do
      let c ← SEff.count V vs cnt
      let b := V.mem.fresh V.ctx.who.thread (V.k + n)
      if (M b).isSome then throw (.unsupported "alloca number in use")
      let l := V.ctx.prog.layout
      pure fun c' => if c' = b then
        sig.metaAt (V.mem.alloc l l.allocaSpace (c * l.size t) (al.getD (l.align t))
          (!(res.any (lifetimeStarted V.ctx V.fn))) false (.thread V.ctx.who.thread)
          (V.ctx.addr (Nat.pair (V.k + n) 0)) (V.ctx.addr (Nat.pair (V.k + n) 1))
          (num := some b)).1.blocks b
        else M c'
    | _ => throw (.unsupported "symbolic alloca at no alloca")

/-- On memory `m` with metadata `M`, an effect that succeeds on `M` (`SEff.applyMeta`) succeeds
(`SEff.apply`), and the memory it leaves has the metadata it leaves, for every valuation, node
values and effect. -/
theorem MetaAgree.apply {m : Mem} {M M' : Metas} (h : MetaAgree m M) {V : Valuation}
    {vs : List (Except Fault Val)} {e : SEff} (hw : e.applyMeta V vs M = .ok M') :
    ∃ m', e.apply V vs m = .ok m' ∧ MetaAgree m' M' := by
  cases e with
  | load lbl pc p =>
    simp only [SEff.applyMeta] at hw
    simp only [SEff.apply]
    split at hw
    · next heq =>
      simp only [heq]
      cases h1 : p.eval V vs with
      | error => simp [h1, bind, Except.bind] at hw
      | ok x =>
        cases h2 : x.addr? with
        | error => simp [h1, h2, bind, Except.bind] at hw
        | ok q =>
          simp [h1, h2, bind, Except.bind, pure, Except.pure] at hw ⊢
          exact hw ▸ h
    · simp [throw, throwThe, MonadExceptOf.throw] at hw
  | store lbl pc v p =>
    simp only [SEff.applyMeta] at hw
    simp only [SEff.apply]
    split at hw
    · next heq =>
      simp only [heq]
      cases h0 : v.eval V vs with
      | error => simp [h0, bind, Except.bind] at hw
      | ok x =>
      cases h1 : p.eval V vs with
      | error => simp [h0, h1, bind, Except.bind] at hw
      | ok y =>
      cases h2 : y.addr? with
      | error => simp [h0, h1, h2, bind, Except.bind] at hw
      | ok q =>
      simp only [h0, h1, h2, bind, Except.bind] at hw
      split at hw
      · next bs h3 =>
        split at hw
        · cases hw
        · next u h4 =>
          obtain ⟨m', hm', hA⟩ := h.write h4
          simp only [pure, Except.pure, Except.ok.injEq] at hw
          subst hw
          simp [Mem.store, h2, h3, hm', bind, Except.bind, pure, Except.pure]
          exact hA
      · simp [throw, throwThe, MonadExceptOf.throw] at hw
    · simp [throw, throwThe, MonadExceptOf.throw] at hw
  | alloca lbl pc n cnt =>
    simp only [SEff.applyMeta] at hw
    simp only [SEff.apply]
    split at hw
    · next heq =>
      simp only [heq]
      cases h1 : SEff.count V vs cnt with
      | error => simp [h1, bind, Except.bind] at hw
      | ok c =>
      have hb := h (V.mem.fresh V.ctx.who.thread (V.k + n))
      simp only [sig] at hb
      by_cases h2 : (M (V.mem.fresh V.ctx.who.thread (V.k + n))).isSome
      · simp [h1, h2, bind, Except.bind, throw, throwThe, MonadExceptOf.throw] at hw
      · have h3 : (m.blocks (V.mem.fresh V.ctx.who.thread (V.k + n))).isSome = false := by
          rw [← Option.isSome_map (f := Block.meta), hb]; simpa using h2
        simp [h1, h2, h3, bind, Except.bind, pure, Except.pure] at hw ⊢
        subst hw
        intro c'
        have := h c'
        simp only [sig, Mem.alloc, Mem.set] at this ⊢
        split <;> simp_all
    · simp [throw, throwThe, MonadExceptOf.throw] at hw

/-- The effects `es` in order on metadata (`SEff.applyMeta`), from the entry memory's
(`sig.metaAt` of `V.mem`'s blocks), for every valuation and list of effects. -/
def SEff.runMeta (V : Valuation) (vs : List (Except Fault Val)) (es : List SEff) :
    Except Fault Metas :=
  es.foldlM (SEff.applyMeta V vs) (sig.metaAt V.mem.blocks)

/-- On memory `m` with metadata `M`, effects `es` that succeed on `M` succeed, and the memory they
leave has the metadata they leave, for every list of effects (by induction on it). -/
theorem MetaAgree.foldlM {V : Valuation} {vs : List (Except Fault Val)} :
    ∀ (es : List SEff) {m : Mem} {M M' : Metas}, MetaAgree m M →
      es.foldlM (SEff.applyMeta V vs) M = .ok M' →
      ∃ m', es.foldlM (SEff.apply V vs) m = .ok m' ∧ MetaAgree m' M'
  | [], m, M, M', h, hw => by
    simp [pure, Except.pure] at hw; subst hw; exact ⟨m, rfl, h⟩
  | e :: es, m, M, M', h, hw => by
    simp only [List.foldlM_cons] at hw ⊢
    cases h1 : e.applyMeta V vs M with
    | error => simp [h1, bind, Except.bind] at hw
    | ok M₁ =>
      simp only [h1, bind, Except.bind] at hw
      obtain ⟨m₁, hm₁, hA⟩ := h.apply h1
      obtain ⟨m', hm', hA'⟩ := MetaAgree.foldlM es hA hw
      exact ⟨m', by simp [hm₁, bind, Except.bind, hm'], hA'⟩

/-- On memory `m` with metadata `M`, a write of bytes `bs` that succeeds (`Mem.write`) passes its
checks on `M` (`Metas.write`), and the memory it leaves has metadata `M`, for every memory and
write. -/
theorem MetaAgree.write_ok {m m' : Mem} {M : Metas} (h : MetaAgree m M) {l : Layout} {w : Who}
    {a : Nat} {p : Ptr} {bs : List MemByte} {al : Option Nat}
    (hw : m.write l w a p bs al = .ok m') :
    M.write l w a p bs.length al = .ok () ∧ MetaAgree m' M := by
  have hb := h p.block
  simp only [sig] at hb
  unfold Metas.write
  unfold Mem.write Mem.check at hw
  simp only [Mem.block] at hw
  rw [h.addr] at hw
  cases hm : m.blocks p.block with
  | none => rw [hm] at hw; cases hw
  | some k =>
    rw [hm] at hb hw; rw [← hb]
    simp only [Option.map_some, Block.meta]
    cases ha : M.mem.addr l a p with
    | error e =>
      by_cases h1 : k.live <;> by_cases h2 : k.owner.admits w <;>
        by_cases h3 : (0 ≤ p.off ∧ p.off + (bs.length : Int) ≤ k.size) <;>
        simp [h1, h2, h3, ha, bind, Except.bind, throw, throwThe, MonadExceptOf.throw] at hw
    | ok ad =>
      by_cases h1 : k.live <;> by_cases h2 : k.owner.admits w <;>
        by_cases h3 : (0 ≤ p.off ∧ p.off + (bs.length : Int) ≤ k.size) <;>
        by_cases h4 : k.readOnly <;> rcases al with _ | al <;>
        simp [h1, h2, h3, h4, ha, bind, Except.bind, throw, throwThe, MonadExceptOf.throw, pure,
          Except.pure] at hw ⊢
      all_goals first
        | (subst hw; exact h.set hm rfl)
        | (split_ifs at hw ⊢; simp [h4] at hw ⊢; done)
        | (split_ifs at hw ⊢; simp [h4] at hw ⊢; subst hw; exact ⟨by assumption, h.set hm rfl⟩)

/-- On memory `m` with metadata `M`, an effect that succeeds (`SEff.apply`) succeeds on `M`
(`SEff.applyMeta`), and the memory it leaves has the metadata it leaves, for every valuation,
node values and effect. -/
theorem MetaAgree.apply_ok {m m' : Mem} {M : Metas} (h : MetaAgree m M) {V : Valuation}
    {vs : List (Except Fault Val)} {e : SEff} (hw : e.apply V vs m = .ok m') :
    ∃ M', e.applyMeta V vs M = .ok M' ∧ MetaAgree m' M' := by
  cases e with
  | load lbl pc p =>
    simp only [SEff.apply] at hw
    simp only [SEff.applyMeta]
    split at hw
    · next heq =>
      simp only [heq]
      cases h1 : p.eval V vs with
      | error => simp [h1, bind, Except.bind] at hw
      | ok x =>
        cases h2 : x.addr? with
        | error => simp [h1, h2, bind, Except.bind] at hw
        | ok q =>
          simp [h1, h2, bind, Except.bind, pure, Except.pure] at hw ⊢
          subst hw; exact fun b => h b
    · simp [throw, throwThe, MonadExceptOf.throw] at hw
  | store lbl pc v p =>
    simp only [SEff.apply] at hw
    simp only [SEff.applyMeta]
    split at hw
    · next heq =>
      simp only [heq]
      cases h0 : v.eval V vs with
      | error => simp [h0, bind, Except.bind] at hw
      | ok x =>
      cases h1 : p.eval V vs with
      | error => simp [h0, h1, bind, Except.bind] at hw
      | ok y =>
      cases h2 : y.addr? with
      | error => simp [h0, h1, h2, bind, Except.bind] at hw
      | ok q =>
      simp only [h0, h1, h2, bind, Except.bind, Mem.store] at hw ⊢
      split at hw
      · next bs h3 =>
        split at hw
        · simp at hw
        · next m₁ h4 =>
          obtain ⟨hw', hA⟩ := h.write_ok h4
          simp [pure, Except.pure] at hw
          subst hw
          exact ⟨M, by simp [h3, hw', pure, Except.pure], fun b => hA b⟩
      · simp [throw, throwThe, MonadExceptOf.throw] at hw
    · simp [throw, throwThe, MonadExceptOf.throw] at hw
  | alloca lbl pc n cnt =>
    simp only [SEff.apply] at hw
    simp only [SEff.applyMeta]
    split at hw
    · next heq =>
      simp only [heq]
      cases h1 : SEff.count V vs cnt with
      | error => simp [h1, bind, Except.bind] at hw
      | ok c =>
      have hb := h (V.mem.fresh V.ctx.who.thread (V.k + n))
      simp only [sig] at hb
      by_cases h3 : (m.blocks (V.mem.fresh V.ctx.who.thread (V.k + n))).isSome
      · simp [h1, h3, bind, Except.bind, throw, throwThe, MonadExceptOf.throw] at hw
      · have h2 : (M (V.mem.fresh V.ctx.who.thread (V.k + n))).isSome = false := by
          rw [← hb, Option.isSome_map]; simpa using h3
        simp [h1, h2, h3, bind, Except.bind, pure, Except.pure] at hw ⊢
        subst hw
        intro c'
        have := h c'
        simp only [sig, Mem.alloc, Mem.set] at this ⊢
        split <;> simp_all
    · simp [throw, throwThe, MonadExceptOf.throw] at hw

/-- On memory `m` with metadata `M`, effects `es` that succeed succeed on `M`, and the memory they
leave has the metadata they leave, for every list of effects (by induction on it). -/
theorem MetaAgree.foldlM_ok {V : Valuation} {vs : List (Except Fault Val)} :
    ∀ (es : List SEff) {m m' : Mem} {M : Metas}, MetaAgree m M →
      es.foldlM (SEff.apply V vs) m = .ok m' →
      ∃ M', es.foldlM (SEff.applyMeta V vs) M = .ok M' ∧ MetaAgree m' M'
  | [], m, m', M, h, hw => by
    simp [pure, Except.pure] at hw; subst hw; exact ⟨M, rfl, h⟩
  | e :: es, m, m', M, h, hw => by
    simp only [List.foldlM_cons] at hw ⊢
    cases h1 : e.apply V vs m with
    | error => simp [h1, bind, Except.bind] at hw
    | ok m₁ =>
      simp only [h1, bind, Except.bind] at hw
      obtain ⟨M₁, hM₁, hA⟩ := h.apply_ok h1
      obtain ⟨M', hM', hA'⟩ := MetaAgree.foldlM_ok es hA hw
      exact ⟨M', by simp [hM₁, bind, Except.bind, hM'], hA'⟩

/-- The obligation `Cond.mem es` holds exactly when the effects `es` run on the entry memory's
metadata (`SEff.runMeta`), for every valuation, node values and list of effects: the check on
metadata is sound and complete. -/
theorem SEff.holds_iff_runMeta {V : Valuation} {vs : List (Except Fault Val)} {es : List SEff} :
    Cond.Holds V vs (.mem es) ↔ ∃ M, SEff.runMeta V vs es = .ok M := by
  constructor
  · rintro ⟨m, hm⟩
    obtain ⟨M, hM, -⟩ := MetaAgree.foldlM_ok es (M := sig.metaAt V.mem.blocks) (fun _ => rfl) hm
    exact ⟨M, hM⟩
  · rintro ⟨M, h⟩
    obtain ⟨m, hm, -⟩ := MetaAgree.foldlM es (m := V.mem) (fun _ => rfl) h
    exact ⟨m, hm⟩

/-- When the check on metadata returns a result (`SEff.runMeta`, as a Boolean the kernel
evaluates), the obligation `Cond.mem es` holds, for every valuation, node values and list of
effects (`SEff.holds_iff_runMeta`). -/
theorem SEff.holds_of_runMeta_toBool {V : Valuation} {vs : List (Except Fault Val)}
    {es : List SEff} (h : (SEff.runMeta V vs es).toBool = true) : Cond.Holds V vs (.mem es) := by
  cases hr : SEff.runMeta V vs es with
  | error => simp [hr, Except.toBool] at h
  | ok M => exact SEff.holds_iff_runMeta.2 ⟨M, hr⟩

end MojoProof.Sym
