import MojoProof.Sem.Writes

/-!
# The frame lemma

The frame lemma (L2 of docs/proofs/schedule-owned.md): a step of a thread reads the memory only at
`next`, at the existence, shape, read-only flag and owner of the blocks at the numbers it names
and the number its `alloca` would take, and, of those blocks whose owner admits the thread, at
their liveness and the bytes of its pending reads.

`Mem.Agree w S P m₁ m₂`: `m₁` and `m₂` have the same `next`, and at every number of `S` both have
no block, or blocks with the same shape, read-only flag and owner which, if the owner admits thread
`w`, have the same liveness and the same bytes where a read access of `P` reads (`Reads`,
`Block.Agree`). `Mem.run m ops`: memory `m` with the changes `ops` applied (`Mem.Op`: bytes put
into a block, a block set, a block made live or dead, an event logged).

- `exec_agree` (the frame lemma for statements), for every context, scope `s`, step count `k`,
  frame, statement and memory `m₂`: if `S` has every number the scope names (`Scope.NamesIn`) and
  the number of the thread's `alloca` (`Mem.fresh`), and `s.mem` and `m₂` agree for the thread at
  `S` and the statement's pending accesses (`Stmt.pending`), then if the statement completes on
  `s.mem` with effect `e`, there are changes `ops` such that `e` is `e` with memory `s.mem.run ops`
  (`Eff.withMem`), and the statement completes on `m₂` with `e` with memory `m₂.run ops`.
- `step_agree` (the frame lemma for steps), for every context, thread and memories `m₁` and `m₂`:
  the same for a step of the thread, its pending accesses (`Thread.pending`) and its result
  (`Step.withMem`).
- `step_fault`: under `step_agree`'s hypotheses, a step that faults on `m₁` faults on `m₂`.

So steps of a thread from agreeing memories both fault, or both succeed with the same thread state
and the same changes to their memories.

`exec_agree` and `step_agree` also say where those changes act (`Mem.Op.At m w L N W`): puts
into blocks of `m` whose owner admits the thread, at bytes that a write the ops log (`W`) writes;
a set at a number of `N` with no block in `m`; liveness changes at numbers of `L`; logs of
accesses. For `exec_agree`, `L` is the blocks the thread owns (`Mem.Owned`) and `N` the number
of its `alloca`; for `step_agree`, `L` also has the blocks its frames allocated.

- `Mem.Changes.agree` (the memory part of the disjointness argument): if `m'` is `m` changed as
  a step may change it (`Mem.Changes L N`, MojoProof/Sem/Writes.lean), then `m` and `m'` agree for
  thread `w` at `S` and the reads of `P` if `N` has no number of `S`, no block at a number of `S`
  and `L` admits `w`, and no new access of `m'`'s trace writes a byte that a read of `P` reads in a
  block of `S` that admits `w`.

This module is about the statements and steps of one thread. The uses on grids are in
MojoProof/Sem/Confluence.lean: a thread's step from grids whose memories agree for it
(`Grid.advance_agree`), a step of one thread that leaves the memory agreeing for a thread with
another number (`Grid.advance_agree_other`), and the diamond of docs/proofs/schedule.md
(`Grid.advance_comm`).

`Reads`, `Block.Agree`, `Mem.Agree`, `Mem.Op`, `Mem.apply` and `Mem.run` are defined in
MojoProof/Sem/SigDef.lean, with `sig`, which reaches them.
-/

namespace MojoProof.Sem

open LLVM

variable {S : Nat → Prop}

section Agree

/-- Agreement of blocks is symmetric. -/
theorem Block.Agree.symm {w : Who} {R : Nat → Prop} {x y : Block} (h : x.Agree w R y) :
    y.Agree w R x :=
  ⟨h.shape.symm, h.readOnly.symm, h.owner.symm, fun hw => (h.live (h.owner ▸ hw)).symm,
    fun hw i hi => (h.bytes (h.owner ▸ hw) i hi).symm⟩

/-- Agreement of memories is symmetric. -/
theorem Mem.Agree.symm {w : Who} {P : List Event} {m₁ m₂ : Mem} (h : m₁.Agree w S P m₂) :
    m₂.Agree w S P m₁ := by
  refine ⟨h.next.symm, fun b hb => ?_⟩
  match m₁.blocks b, m₂.blocks b, h.blocks b hb with
  | _, _, .none => exact .none
  | _, _, .some hxy => exact .some hxy.symm

/-- Memories that agree at the numbers of `S` have the same shape there (`Mem.SameShape`). -/
theorem Mem.Agree.sameShape {w : Who} {P : List Event} {m₁ m₂ : Mem} (h : m₁.Agree w S P m₂) :
    m₁.SameShape S m₂ := by
  intro b hb
  match m₁.blocks b, m₂.blocks b, h.blocks b hb with
  | _, _, .none => rfl
  | _, _, .some hxy => exact congrArg some hxy.shape

/-- The block of a number of `S` in the second memory, if the first has one there. -/
theorem Mem.Agree.block {w : Who} {P : List Event} {m₁ m₂ : Mem} (h : m₁.Agree w S P m₂) {b : Nat}
    (hb : S b) {x : Block} (hx : m₁.blocks b = some x) :
    ∃ y, m₂.blocks b = some y ∧ x.Agree w (Reads P b) y := by
  have := h.blocks b hb
  rw [hx] at this
  match m₂.blocks b, this with
  | _, .some hxy => exact ⟨_, rfl, hxy⟩

/-- Memories that agree at the numbers of `S` have a block at the same numbers of `S`. -/
theorem Mem.Agree.isSome {w : Who} {P : List Event} {m₁ m₂ : Mem} (h : m₁.Agree w S P m₂) {b : Nat}
    (hb : S b) : (m₂.blocks b).isSome = (m₁.blocks b).isSome :=
  match m₁.blocks b, m₂.blocks b, h.blocks b hb with
  | _, _, .none => rfl
  | _, _, .some _ => rfl

end Agree

section Ops

/-- The event op `o` logs, if any. -/
def Mem.Op.event : Mem.Op → Option Event
  | .log e => some e
  | _ => none

/-- Where op `o` of a step of thread `w` on memory `m` acts: a put into a block of `m` whose owner
admits `w`, at bytes each of which an access of `W` writes; a set at a number of `N` with no block
in `m`; a liveness change at a number of `L`; a log of an access. -/
def Mem.Op.At (m : Mem) (w : Who) (L N : Nat → Prop) (W : List Event) : Mem.Op → Prop
  | .put b o bs => (∃ x, m.blocks b = some x ∧ x.owner.admits w = true) ∧
      ∀ i, o ≤ i → i < o + bs.length → ∃ a, .access a ∈ W ∧ a.Writes b i
  | .set b _ => N b ∧ m.blocks b = none
  | .live b _ => L b
  | .log e => ∃ a, e = .access a

/-- Where an op acts is kept on a memory with the same blocks, for the same `N`, every `L'` that
has every number of `L` and every list `W'` that has every event of `W`. -/
theorem Mem.Op.At.mono {m m' : Mem} {w : Who} {L L' N : Nat → Prop} {W W' : List Event}
    (hm : m.blocks = m'.blocks) (hL : ∀ b, L b → L' b) (hW : ∀ e ∈ W, e ∈ W') :
    ∀ {o : Mem.Op}, o.At m w L N W → o.At m' w L' N W'
  | .put .., ⟨hx, hb⟩ => ⟨by rw [← hm]; exact hx,
      fun i h₁ h₂ => (hb i h₁ h₂).imp fun _ h => ⟨hW _ h.1, h.2⟩⟩
  | .set .., ⟨hN, hb⟩ => ⟨hN, by rw [← hm]; exact hb⟩
  | .live .., h => hL _ h
  | .log _, h => h

/-- Making each block of `bs` live or dead in turn runs the ops `.live b v` for the `b` of `bs`,
in order. -/
theorem Mem.foldl_setLive_run (m : Mem) (bs : List Nat) (v : Bool) :
    bs.foldl (fun m b => m.setLive b v) m = m.run (bs.map (.live · v)) := by
  induction bs generalizing m with
  | nil => rfl
  | cons b bs ih => exact ih _

/-- A change keeps the shape of every block: memories of the same shape at the numbers of `S`
have the same shape there after it. -/
theorem Mem.SameShape.apply {m₁ m₂ : Mem} (h : m₁.SameShape S m₂) :
    ∀ op : Mem.Op, (m₁.apply op).SameShape S (m₂.apply op)
  | .put b o bs => fun c hc => by
    have := h c hc
    simp only [Mem.apply]
    cases h₁ : m₁.blocks b <;> cases h₂ : m₂.blocks b <;> by_cases e : c = b <;>
      simp_all [Mem.set, Block.put, Block.shape]
  | .set b x => fun c hc => by
    by_cases e : c = b
    · simp [Mem.apply, Mem.set, e]
    · simpa [Mem.apply, Mem.set, e] using h c hc
  | .live b v => fun c hc => by
    have := h c hc
    simp only [Mem.apply, Mem.setLive]
    cases h₁ : m₁.blocks b <;> cases h₂ : m₂.blocks b <;> by_cases e : c = b <;>
      simp_all [Mem.set, Block.shape]
  | .log e => fun c hc => h c hc

/-- Memories with the same shape at the numbers of `S` have the same shape there after the same
changes `ops`. -/
theorem Mem.SameShape.run {m₁ m₂ : Mem} (h : m₁.SameShape S m₂) :
    ∀ ops : List Mem.Op, (m₁.run ops).SameShape S (m₂.run ops)
  | [] => h
  | op :: ops => Mem.SameShape.run (h.apply op) ops

end Ops

section Memory

variable {w : Who} {P : List Event} {m₁ m₂ : Mem} {l : Layout} {a n : Nat} {p : Ptr}
  {al : Option Nat}

/-- A check of an access to a block of `S` that succeeds on `m₁` succeeds on `m₂`, at the block
of `m₂` there, which agrees with that of `m₁` and has an owner that admits the thread. -/
theorem Mem.check_agree (h : m₁.Agree w S P m₂) (hp : S p.block) {x : Block} {o : Nat}
    (he : m₁.check l w a p n al = .ok (x, o)) :
    ∃ y, m₂.blocks p.block = some y ∧ x.Agree w (Reads P p.block) y ∧ x.owner.admits w ∧
      m₂.check l w a p n al = .ok (y, o) := by
  obtain ⟨hx, hl, hw, hb, ad, had, hal, rfl⟩ := Mem.check_inv he
  obtain ⟨y, hy, hxy⟩ := h.block hp hx
  have hl' : y.live = true := (hxy.live hw) ▸ hl
  have hw' : y.owner.admits w = true := hxy.owner ▸ hw
  have hz : y.size = x.size := congrArg (·.2.1) hxy.shape.symm
  refine ⟨y, hy, hxy, hw, ?_⟩
  simp only [Mem.check, Mem.block, hy, hl', hw', hz, hb, ← Mem.addr_shape h.sameShape hp l a, had,
    bind, Except.bind, pure, Except.pure, and_self, ↓reduceIte]
  cases al <;> simp [hal]

/-- A load from a block of `S` whose bytes a read of `P` reads gives on `m₂` what it gives on
`m₁`. -/
theorem Mem.load_agree (h : m₁.Agree w S P m₂) (hp : S p.block) {t : Ty} {v : Val} {w' : Who}
    {op : Option RmwOp} {inv : Bool} (hP : .access ⟨w', p, l.stored t, false, op, inv⟩ ∈ P)
    (he : m₁.load l w a t p al = .ok v) : m₂.load l w a t p al = .ok v := by
  unfold Mem.load at he ⊢
  simp only [bind, Except.bind] at he ⊢
  split at he
  · cases he
  · rename_i r hc
    obtain ⟨x, o⟩ := r
    obtain ⟨y, -, hxy, hw, hc₂⟩ := Mem.check_agree h hp hc
    obtain ⟨h0, rfl⟩ := Mem.check_off hc
    rw [hc₂]
    have hr : y.read p.off.toNat (l.stored t) = x.read p.off.toNat (l.stored t) := by
      refine List.map_congr_left fun i hi => (hxy.bytes hw _ ⟨_, hP, rfl, rfl, ?_, ?_⟩).symm
      all_goals
        have := List.mem_range.1 hi
        dsimp only
        omega
    simpa only [hr] using he

/-- A write to a block of `S` that succeeds on `m₁` succeeds on `m₂`, and both put the bytes
there. -/
theorem Mem.write_agree (h : m₁.Agree w S P m₂) (hp : S p.block) {bs : List MemByte} {m' : Mem}
    (he : m₁.write l w a p bs al = .ok m') :
    (∃ x, m₁.blocks p.block = some x ∧ x.owner.admits w = true) ∧ 0 ≤ p.off ∧
      m' = m₁.run [.put p.block p.off.toNat bs] ∧
      m₂.write l w a p bs al = .ok (m₂.run [.put p.block p.off.toNat bs]) := by
  unfold Mem.write at he ⊢
  simp only [bind, Except.bind, pure, Except.pure] at he ⊢
  split at he
  · cases he
  · rename_i r hc
    obtain ⟨x, o⟩ := r
    obtain ⟨y, hy, hxy, -, hc₂⟩ := Mem.check_agree h hp hc
    obtain ⟨h0, rfl⟩ := Mem.check_off hc
    refine ⟨⟨x, Mem.check_block hc⟩, h0, ?_⟩
    rw [hc₂]
    dsimp only at he ⊢
    rw [← hxy.readOnly]
    split at he
    · cases he
    · cases he
      simp [Mem.run, Mem.apply, (Mem.check_block hc).1, *]

/-- A store to a block of `S` that succeeds on `m₁` succeeds on `m₂`, with the same changes: a
put into a block of `m₁` that admits the thread, at the bytes of the write it logs, and the log. -/
theorem Mem.store_agree (h : m₁.Agree w S P m₂) (hp : S p.block) {t : Ty} {v : Val}
    {op : Option RmwOp} {m' : Mem} (he : m₁.store l w a t v p al op = .ok m') :
    ∃ ops, (∀ o ∈ ops, ∀ L N, o.At m₁ w L N (ops.filterMap Mem.Op.event)) ∧ m' = m₁.run ops ∧
      m₂.store l w a t v p al op = .ok (m₂.run ops) := by
  unfold Mem.store at he ⊢
  cases hbs : l.encode t v with
  | none => simp [hbs] at he
  | some bs =>
    simp only [hbs, bind, Except.bind, pure, Except.pure] at he ⊢
    split at he
    · cases he
    · rename_i m₃ hw
      cases he
      obtain ⟨hx, h0, rfl, hw₂⟩ := Mem.write_agree h hp hw
      refine ⟨[.put p.block p.off.toNat bs, .log (.access ⟨w, p, bs.length, true, op, false⟩)],
        fun o ho L N => ?_, rfl, by rw [hw₂]; rfl⟩
      simp only [List.mem_cons, List.not_mem_nil, or_false] at ho
      rcases ho with rfl | rfl
      · exact ⟨hx, fun i h₁ h₂ => ⟨⟨w, p, bs.length, true, op, false⟩, by simp [Mem.Op.event],
          rfl, rfl, show p.off ≤ (i : Int) by omega, show (i : Int) < p.off + bs.length by omega⟩⟩
      · exact ⟨_, rfl⟩

end Memory

section Shape

/-- `foldlM` of functions that agree on an invariant of the accumulator. -/
theorem foldlM_congr {α β ε : Type} {f g : β → α → Except ε β} {P : β → Prop}
    (hP : ∀ b a b', P b → f b a = .ok b' → P b') (hfg : ∀ b a, P b → f b a = g b a) :
    ∀ (xs : List α) (b : β), P b → xs.foldlM f b = xs.foldlM g b
  | [], _, _ => rfl
  | a :: xs, b, hb => by
    rw [List.foldlM_cons, List.foldlM_cons, ← hfg b a hb]
    cases hf : f b a with
    | error e => rfl
    | ok b' => exact foldlM_congr hP hfg xs b' (hP b a b' hb hf)

/-- `lanes2` of two functions that agree on operands that name only numbers of `S` gives the same
on such operands. -/
theorem lanes2_congr {F G : Nat → Val → Val → Except Fault Val}
    (hFG : ∀ i x y, x.NamesIn S → y.NamesIn S → F i x y = G i x y) {x y : Val}
    (hx : x.NamesIn S) (hy : y.NamesIn S) : lanes2 F x y = lanes2 G x y := by
  unfold lanes2
  split
  · split
    · rw [mapM_congr (g := fun ((x, y), i) => G i x y) fun q hm => ?_]
      obtain ⟨⟨u, v⟩, i⟩ := q
      have hm' := List.of_mem_zip (List.fst_mem_of_mem_zipIdx hm)
      exact hFG i u v (Val.allNamesIn_iff.1 hx u hm'.1) (Val.allNamesIn_iff.1 hy v hm'.2)
    · rfl
  · exact hFG 0 _ _ hx hy

/-- An `icmp` of operands that name only numbers of `S` gives the same on memories with the same
shape at the numbers of `S`: it reads only the addresses of the blocks they name. -/
theorem icmpV_shape {m m' : Mem} (h : m.SameShape S m') {x y : Val} (hx : x.NamesIn S)
    (hy : y.NamesIn S) l p t : icmpV l m p t x y = icmpV l m' p t x y := by
  unfold icmpV
  refine lanes2_congr (fun i u v hu hv => ?_) hx hy
  cases u <;> cases v <;> try rfl
  simp only [strict2]
  generalize t.elt = e
  cases e <;> first | rfl | simp only [Mem.addr_shape h hu, Mem.addr_shape h hv]

/-- A value that names only numbers of `S`, under attributes (`withAttrs`), gives the same on
memories with the same shape at the numbers of `S`. -/
theorem withAttrs_shape {m m' : Mem} (h : m.SameShape S m') {v : Val} (hv : v.NamesIn S) l t
    attrs : withAttrs l m t attrs v = withAttrs l m' t attrs v := by
  simp only [withAttrs]
  split
  case' h_1 =>
    congr 2
    refine mapM_congr fun x hx => ?_
    refine foldlM_congr (P := fun r : Val => r.NamesIn S) ?_ ?_ _ _ (Val.allNamesIn_iff.1 hv x hx)
  case' h_2 =>
    congr 1
    refine foldlM_congr (P := fun r : Val => r.NamesIn S) ?_ ?_ _ _ hv
  all_goals first
    | (intro b a b' hb hs
       simp only [bind, Except.bind, pure, Except.pure] at hs
       repeat' split at hs
       all_goals cases hs
       all_goals first | exact hb | trivial)
    | (intro b a hb
       split <;> first | rfl | simp only [Mem.addr_shape h hb])

end Shape

section Exec

/-- The owners of the blocks of `S` are those of `m₁`. -/
theorem Mem.Agree.owner {w : Who} {P : List Event} {m₁ m₂ : Mem} (h : m₁.Agree w S P m₂) {b : Nat}
    (hb : S b) : (m₂.blocks b).map (·.owner) = (m₁.blocks b).map (·.owner) :=
  match m₁.blocks b, m₂.blocks b, h.blocks b hb with
  | _, _, .none => rfl
  | _, _, .some hxy => congrArg some hxy.owner.symm

/-- The changes intrinsic `i` on `args` makes to the memory: `llvm.lifetime.start` and `.end` on
a pointer make its block live or dead; no other intrinsic changes it. -/
def _root_.MojoProof.LLVM.Intrinsic.ops : Intrinsic → List Val → List Mem.Op
  | .lifetime start, [.ptr p] => [.live p.block start]
  | _, _ => []

/-- An intrinsic reads the memory only at the owners of the blocks its pointer arguments name: on
a memory `m` with those owners it gives the same fault or result, and `m` with the changes
`Intrinsic.ops`. -/
theorem intrinsic_agree {c : Ctx} {s : Scope} {m : Mem} {fm : FastMath} {i : Intrinsic}
    {vs : List Val} (ho : ∀ b, S b → (m.blocks b).map (·.owner) = (s.mem.blocks b).map (·.owner))
    (hvs : ∀ x ∈ vs, x.NamesIn S) :
    intrinsic c { s with mem := m } fm i vs =
      (intrinsic c s fm i vs).map (Option.map fun x => (x.1, m.run (i.ops vs))) := by
  by_cases hl : ∃ start p, i = .lifetime start ∧ vs = [.ptr p]
  · obtain ⟨start, p, rfl, rfl⟩ := hl
    have e := congrArg (Option.any (· == Owner.thread c.who.thread))
      (ho _ (hvs _ List.mem_cons_self))
    simp only [Option.any_map] at e
    simp only [intrinsic, Mem.block, Intrinsic.ops, e]
    split <;> rename_i hc <;> simp only [hc, ↓reduceIte] <;> rfl
  · cases h : intrinsic c s fm i vs <;>
    · unfold intrinsic at h ⊢
      repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
      all_goals cases h
      all_goals first
        | rfl
        | (exfalso; exact hl ⟨_, _, rfl, rfl⟩)
        | simp [bind, Except.bind, pure, Except.pure, Except.map, *]
      all_goals rfl

/-- `intrinsic_agree` on the scope's own memory: an intrinsic that completes changes the memory
by `Intrinsic.ops`. -/
theorem intrinsic_run {c : Ctx} {s : Scope} {fm : FastMath} {i : Intrinsic} {vs : List Val}
    {v : Option Val} {m' : Mem} (hvs : ∀ x ∈ vs, x.NamesIn S)
    (h : intrinsic c s fm i vs = .ok (some (v, m'))) : m' = s.mem.run (i.ops vs) := by
  have := intrinsic_agree (c := c) (s := s) (fm := fm) (i := i) (fun _ _ => rfl) hvs
  rw [h] at this
  simp only [Except.map, Option.map_some] at this
  injection this with this
  injection this with this
  injection this

/-- An intrinsic that completes makes its changes (`Intrinsic.ops`) at blocks the thread owns. -/
theorem intrinsic_at {c : Ctx} {s : Scope} {fm : FastMath} {i : Intrinsic} {vs : List Val}
    {r : Option Val × Mem} (h : intrinsic c s fm i vs = .ok (some r)) :
    ∀ o ∈ i.ops vs, ∀ N W, o.At s.mem c.who (s.mem.Owned c.who.thread) N W := by
  intro o ho N W
  unfold Intrinsic.ops at ho
  split at ho
  · rw [List.mem_singleton] at ho
    subst ho
    rename_i start p
    simp only [intrinsic, Mem.block] at h
    by_cases hb : ((s.mem.blocks p.block).any fun b => b.owner == .thread c.who.thread) = true
    · obtain ⟨x, hx, ho⟩ := (Option.any_eq_true _ _).1 hb
      exact ⟨x, hx, by simpa using ho⟩
    · simp only [hb, Bool.false_eq_true, ↓reduceIte] at h
      cases h
  · cases ho

/-- Whether an intrinsic's result is undefined before fast-math flags (`ownUndef`), on arguments
that name only numbers of `S`, is the same on every memory with the owners of `s.mem` at `S`. -/
theorem ownUndef_agree {c : Ctx} {s : Scope} {m : Mem} {i : Intrinsic} {vs : List Val}
    (ho : ∀ b, S b → (m.blocks b).map (·.owner) = (s.mem.blocks b).map (·.owner))
    (hvs : ∀ x ∈ vs, x.NamesIn S) : ownUndef c { s with mem := m } i vs = ownUndef c s i vs := by
  unfold ownUndef
  rw [intrinsic_agree ho hvs]
  rcases intrinsic c s {} i vs with _ | _ | ⟨_ | _, _⟩ <;> rfl

/-- Effect `e` with its memory, if it continues, replaced by `m`. -/
def Eff.withMem (m : Mem) : Eff → Eff
  | .next f _ => .next f m
  | e => e

/-- Logging the same event on two memories that agree keeps them agreeing. -/
theorem Mem.Agree.log {w : Who} {P : List Event} {m₁ m₂ : Mem} (h : m₁.Agree w S P m₂) (e : Event) :
    (m₁.log e).Agree w S P (m₂.log e) :=
  ⟨h.next, h.blocks⟩

/-- An access through a value whose pointers name numbers of `S` is to a block of `S`. -/
theorem Val.addr?_namesIn {x : Val} {q : Ptr} (h : x.addr? = .ok q) (hx : x.NamesIn S) :
    S q.block := by
  cases x <;> first | (cases h; exact hx) | cases h

/-- `withAttrs_shape` under `Option.mapM`. -/
theorem Option.mapM_withAttrs_shape {m m' : Mem} (h : m.SameShape S m') {v : Option Val}
    (hv : ∀ x, v = some x → x.NamesIn S) l t attrs :
    v.mapM (withAttrs l m t attrs) = v.mapM (withAttrs l m' t attrs) := by
  cases v
  · rfl
  · exact congrArg (some <$> ·) (withAttrs_shape h (hv _ rfl) ..)

/-- `withAttrs_shape` for the arguments of a call. -/
theorem mapM_withAttrs_shape {m m' : Mem} (h : m.SameShape S m') {vs : List Val}
    (hvs : ∀ x ∈ vs, x.NamesIn S) (l : Layout) (ps : List Param)
    (args : List (TValue × List Attr)) :
    ((ps.zip vs).zip args).mapM (fun x => withAttrs l m x.1.1.ty (x.1.1.attrs ++ x.2.2) x.1.2) =
      ((ps.zip vs).zip args).mapM fun x => withAttrs l m' x.1.1.ty (x.1.1.attrs ++ x.2.2) x.1.2 :=
  mapM_congr fun ⟨⟨_, v⟩, _, _⟩ hq =>
    withAttrs_shape h (hvs v (List.of_mem_zip (List.of_mem_zip hq).1).2) ..

set_option maxHeartbeats 400000 in
/-- `exec_agree` for a call of a function. -/
theorem exec_agree_call {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {P : List Event} {e : Eff}
    {m₂ : Mem} (hs : s.NamesIn S) (h : s.mem.Agree c.who S P m₂) res fm ret g args md
    (he : exec c s k f ⟨res, .call fm ret (.fn g) args, md⟩ = .ok e) :
    ∃ ops, (∀ o ∈ ops, o.At s.mem c.who (s.mem.Owned c.who.thread) (· = s.mem.fresh c.who.thread k)
        (ops.filterMap Mem.Op.event)) ∧ e = e.withMem (s.mem.run ops) ∧
      exec c { s with mem := m₂ } k f ⟨res, .call fm ret (.fn g) args, md⟩ =
        .ok (e.withMem (m₂.run ops)) := by
  have t1 : ∀ v, evalTV { s with mem := m₂ } v = evalTV s v := fun v =>
    (evalTV_shape hs h.sameShape v).1
  have h' := h.symm.sameShape
  simp only [exec, bind, Except.bind, pure, Except.pure] at he
  repeat' split at he
  all_goals cases he
  all_goals try cases ‹throw _ = Except.ok _›
  all_goals
    have hvs : ∀ x : Val, x ∈ _ → x.NamesIn S :=
      mapM_mem (f := fun x : TValue × List Attr => evalTV s x.1) ‹_› fun q _ y hy =>
        (evalTV_shape hs h.sameShape q.1).2 y hy
    have hvs' : ∀ x : Val, x ∈ _ → x.NamesIn S :=
      mapM_mem (f := fun x : (Param × Val) × TValue × List Attr =>
        withAttrs c.prog.layout s.mem x.1.1.ty (x.1.1.attrs ++ x.2.2) x.1.2) ‹_› fun q hq w hw => by
        obtain ⟨⟨p, v⟩, tv, as⟩ := q
        exact withAttrs_namesIn hw (hvs v (List.of_mem_zip (List.of_mem_zip hq).1).2)
    have ho : ∀ b, S b → (m₂.blocks b).map (·.owner) = (s.mem.blocks b).map (·.owner) :=
      fun b hb => h.owner hb
    -- The intrinsic `exec` looks up twice, once to tell a float intrinsic.
    try
      have e := (‹List.lookup g c.prog.intrinsics = some (.fminmax _ _)›).symm.trans
        ‹List.lookup g c.prog.intrinsics = some _›
      cases e
    try
      have e := (‹List.lookup g c.prog.intrinsics = some .rsqrtApprox›).symm.trans
        ‹List.lookup g c.prog.intrinsics = some _›
      cases e
    try simp only [Bool.false_and, Bool.or_false] at ‹(_ || false && _) = true›
    first
      | (have hi := (intrinsic_namesIn ‹intrinsic _ _ _ _ _ = Except.ok (some _)› hvs').1
         have ha := intrinsic_at ‹intrinsic _ _ _ _ _ = Except.ok (some _)›
         obtain rfl := intrinsic_run hvs' ‹intrinsic _ _ _ _ _ = Except.ok (some _)›
         refine ⟨_, fun o ho => ha o ho _ _, rfl, ?_⟩
         simp only [exec, bind, Except.bind, pure, Except.pure, mapM_withAttrs_shape h' hvs,
           intrinsic_agree ho hvs', ownUndef_agree ho hvs', Except.map, Option.map_some,
           Option.mapM_withAttrs_shape (h'.run _) hi, Eff.withMem, Bool.true_or, Bool.false_eq_true,
           ↓reduceIte, *])
      | (refine ⟨[], List.forall_mem_nil _, rfl, ?_⟩
         simp only [exec, bind, Except.bind, pure, Except.pure, mapM_withAttrs_shape h' hvs,
           intrinsic_agree ho hvs', Except.map, Option.map_none,
           Eff.withMem, Bool.true_or, Bool.false_eq_true, ↓reduceIte, *])

set_option maxHeartbeats 400000 in
/-- **The frame lemma for statements.** For every context, scope `s`, step count `k`, frame,
statement and memory `m₂`: if `S` has every number `s` names and the number the thread's `alloca`
takes, and `s.mem` and `m₂` agree for the thread at `S` and the statement's pending accesses, then a
statement that completes on `s.mem` completes on `m₂` with the same effect, both changing their
memory by the same changes `ops`. Those are at the places `Mem.Op.At` gives: puts at the bytes of
writes it logs, into blocks of `s.mem` whose owner admits the thread, a set at the `alloca`'s
number, liveness changes of blocks the thread owns, and logs of accesses. -/
theorem exec_agree {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {e : Eff} {m₂ : Mem}
    (hs : s.NamesIn S) (hk : S (s.mem.fresh c.who.thread k))
    (h : s.mem.Agree c.who S (st.pending c s) m₂) (he : exec c s k f st = .ok e) :
    ∃ ops, (∀ o ∈ ops, o.At s.mem c.who (s.mem.Owned c.who.thread) (· = s.mem.fresh c.who.thread k)
        (ops.filterMap Mem.Op.event)) ∧ e = e.withMem (s.mem.run ops) ∧
      exec c { s with mem := m₂ } k f st = .ok (e.withMem (m₂.run ops)) := by
  obtain ⟨res, inst, md⟩ := st
  by_cases hc : ∃ fm ret g args, inst = .call fm ret (.fn g) args
  · obtain ⟨fm, ret, g, args, rfl⟩ := hc
    exact exec_agree_call hs h res fm ret g args md he
  have e1 : ∀ t v, evalV { s with mem := m₂ } t v = evalV s t v := fun t v =>
    (evalV_shape hs h.sameShape t v).1
  have e2 : ∀ t v x, evalV s t v = .ok x → x.NamesIn S := fun t v =>
    (evalV_shape hs h.sameShape t v).2
  have t1 : ∀ v, evalTV { s with mem := m₂ } v = evalTV s v := fun v =>
    (evalTV_shape hs h.sameShape v).1
  have t2 : ∀ vs, evalTVs { s with mem := m₂ } vs = evalTVs s vs := fun vs =>
    (evalTVs_shape hs h.sameShape vs).1
  have hn : m₂.fresh c.who.thread k = s.mem.fresh c.who.thread k := by
    simp only [Mem.fresh, h.next]
  have hb := h.isSome hk
  have h' := h.symm.sameShape
  -- Destructure the operands and types `exec` matches on, so that `simp` reduces its `match`.
  rcases inst with _ | _ | ⟨_, ⟨_, _⟩⟩ | _ | _ | ⟨_, ⟨_, _⟩, _⟩ | ⟨⟨_, _⟩, ⟨_, _⟩, ⟨_, _⟩⟩ | _ | _ |
    ⟨_, _, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, _⟩ |
    ⟨_, ⟨_, _⟩, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, _⟩ |
    ⟨_, _, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, _⟩ | ⟨⟨_, _⟩, _⟩ | ⟨⟨_, _⟩, ⟨_, _⟩, _⟩ |
    ⟨⟨_, _⟩, _⟩ | ⟨⟨_, _⟩, _, _⟩ | ⟨⟨_, _⟩, _, _⟩ | ⟨_, _, (_ | _), _⟩ |
    ⟨_, _, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, ⟨_, _⟩, _, _, _⟩ <;>
  first
  | exact absurd ⟨_, _, _, _, rfl⟩ hc
  | (simp only [exec, bind, Except.bind, pure, Except.pure, Mem.alloc] at he
     repeat' split at he
     all_goals cases he
     all_goals first
       | cases ‹throw _ = Except.ok _›
       | (have hq := Val.addr?_namesIn ‹Val.addr? _ = .ok _› (e2 _ _ _ ‹_›)
          simp only [LLVM.Stmt.pending, bind, Except.bind, *] at h
          first
            | (have hl := Mem.load_agree h hq List.mem_cons_self ‹Mem.load _ _ _ _ _ _ _ = .ok _›
               refine ⟨[.log _], fun o ho => by
                 rw [List.mem_singleton] at ho
                 subst ho
                 exact ⟨_, rfl⟩, rfl, ?_⟩
               simp only [exec, bind, Except.bind, pure, Except.pure, Eff.withMem, Mem.run,
                 Mem.apply, List.foldl, ↓reduceIte, Bool.false_eq_true, *])
            | (obtain ⟨ops, ha, rfl, h₂⟩ := Mem.store_agree h hq
                 ‹Mem.store _ _ _ _ _ _ _ _ _ = .ok _›
               refine ⟨ops, fun o ho => ha o ho _ _, rfl, ?_⟩
               simp only [exec, bind, Except.bind, pure, Except.pure, Eff.withMem, *])
            | (have hl := Mem.load_agree h hq (List.mem_cons_of_mem _ List.mem_cons_self)
                 ‹Mem.load _ _ _ _ _ _ _ = .ok _›
               obtain ⟨ops, ha, rfl, h₂⟩ := Mem.store_agree (h.log _) hq
                 ‹Mem.store _ _ _ _ _ _ _ _ _ = .ok _›
               refine ⟨.log _ :: ops, fun o ho => ?_, rfl, ?_⟩
               · rcases List.mem_cons.1 ho with rfl | ho
                 · exact ⟨_, rfl⟩
                 · exact (ha o ho _ _).mono rfl (fun _ => id) fun _ =>
                     List.mem_cons_of_mem _
               simp only [exec, bind, Except.bind, pure, Except.pure, Eff.withMem, Mem.run,
                 Mem.apply, List.foldl, ↓reduceIte, *]))
       | (have : ¬(s.mem.blocks (s.mem.fresh c.who.thread k)).isSome = true := ‹_›
          refine ⟨[.set _ _], fun o ho => by
            rw [List.mem_singleton] at ho
            subst ho
            exact ⟨rfl, by simpa using this⟩, rfl, ?_⟩
          simp only [exec, bind, Except.bind, pure, Except.pure, Mem.alloc, Eff.withMem, Mem.run,
            Mem.apply, List.foldl, ↓reduceIte, Bool.false_eq_true, *])
       | (refine ⟨[], List.forall_mem_nil _, rfl, ?_⟩
          simp (disch := first | assumption | (apply e2; assumption)) only [exec, bind,
            Except.bind, pure, Except.pure, icmpV_shape h', castV_shape h', gep_shape h',
            Eff.withMem, Mem.run, List.foldl, ↓reduceIte, Bool.false_eq_true, *]))

/-- `withAttrs_shape` for the value a `ret` returns. -/
theorem ret_shape {c : Ctx} {f : Frame} {k : Nat} {m₁ m₂ : Mem} (hs : (c.scope m₁ f k).NamesIn S)
    (h : m₁.SameShape S m₂) (rv : Option TValue) :
    rv.mapM (fun tv => evalTV (c.scope m₂ f k) tv >>=
        withAttrs (c.scope m₂ f k).layout m₂ f.fn.ret f.fn.retAttrs) =
      rv.mapM fun tv => evalTV (c.scope m₁ f k) tv >>=
        withAttrs (c.scope m₁ f k).layout m₁ f.fn.ret f.fn.retAttrs := by
  cases rv with
  | none => rfl
  | some tv =>
    have e : evalTV (c.scope m₂ f k) tv = evalTV (c.scope m₁ f k) tv := (evalTV_shape hs h tv).1
    rw [Option.mapM_some, Option.mapM_some, e]
    cases hv : evalTV (c.scope m₁ f k) tv with
    | error => rfl
    | ok v =>
      exact congrArg (some <$> ·) (withAttrs_shape (fun b hb => (h b hb).symm)
        ((evalTV_shape hs h tv).2 v hv) ..)

/-- Step result `r` with its memory, if it has one, replaced by `m`. -/
def Step.withMem (m : Mem) : Step → Step
  | .next t _ => .next t m
  | .done _ => .done m
  | r => r

/-- **The frame lemma for steps.** For every context, thread and memories `m₁` and `m₂`: if `m₁` and
`m₂` agree for the thread (`Mem.Agree`) at the numbers of `S`, which has every number the scope of
the thread's innermost frame names and the number its `alloca` would take, at the bytes of the
thread's pending reads, then a step of the thread on `m₁` that succeeds succeeds on `m₂` with the
same result, and both change their memory by the same changes `ops`. Those are at the places
`Mem.Op.At` gives, with liveness changes of blocks the thread owns or its frames allocated, a set at
the number its `alloca` would take, and puts at the bytes of writes the ops log. -/
theorem step_agree {c : Ctx} {t : Thread} {m₁ m₂ : Mem} {r : Step}
    (hs : ∀ f, t.frames.head? = some f → (c.scope m₁ f t.k).NamesIn S)
    (hk : S (m₁.fresh c.who.thread t.k)) (h : m₁.Agree c.who S (t.pending c m₁) m₂)
    (he : step c t m₁ = .ok r) :
    ∃ ops, (∀ o ∈ ops, o.At m₁ c.who (fun b => m₁.Owned c.who.thread b ∨ ∃ f ∈ t.frames,
        b ∈ f.allocas) (· = m₁.fresh c.who.thread t.k) (ops.filterMap Mem.Op.event)) ∧
      r = r.withMem (m₁.run ops) ∧ step c t m₂ = .ok (r.withMem (m₂.run ops)) := by
  obtain ⟨_ | ⟨f, rest⟩, k⟩ := t
  · simp only [step] at he
    cases he
  have hs := hs f rfl
  have e1 : ∀ t v, evalV (c.scope m₂ f k) t v = evalV (c.scope m₁ f k) t v := fun t v =>
    (evalV_shape hs h.sameShape t v).1
  have en : ∀ d, enter (c.scope m₂ f k) f d = enter (c.scope m₁ f k) f d := fun d => by
    simp only [enter, e1]
  have hx : ∀ b, f.fn.blocks.find? (·.label == f.label) = some b → ∀ (hpc : f.pc < b.stmts.size) e,
      exec c (c.scope m₁ f k) k f b.stmts[f.pc] = .ok e → ∃ ops, (∀ o ∈ ops, o.At m₁ c.who
        (m₁.Owned c.who.thread) (· = m₁.fresh c.who.thread k) (ops.filterMap Mem.Op.event)) ∧
        e = e.withMem (m₁.run ops) ∧
        exec c (c.scope m₂ f k) k f b.stmts[f.pc] = .ok (e.withMem (m₂.run ops)) := by
    intro b hb hpc e he
    refine exec_agree hs hk ?_ he
    simp only [Thread.pending, hb, getElem?_pos, hpc] at h
    exact h
  simp only [step, bind, Except.bind, pure, Except.pure] at he
  repeat' split at he
  all_goals cases he
  all_goals try cases ‹throw _ = Except.ok _›
  all_goals first
    | (have hx := hx _ ‹_› ‹_› _ ‹exec _ _ _ _ _ = Except.ok _›
       obtain ⟨ops, ha, h1, h2⟩ := hx
       simp only [Eff.withMem, Eff.next.injEq, true_and] at h1
       simp only [Eff.withMem] at h2
       first
         | (subst h1
            refine ⟨ops, fun o ho => (ha o ho).mono rfl (fun _ => Or.inl) fun _ => id, rfl, ?_⟩)
         | refine ⟨[], List.forall_mem_nil _, rfl, ?_⟩
       simp only [step, bind, Except.bind, pure, Except.pure, Step.withMem, Mem.run, List.foldl,
         ↓reduceDIte, ↓reduceIte, Bool.false_eq_true, *])
    | (have hv := (ret_shape hs h.sameShape _).trans ‹Option.mapM _ _ = Except.ok _›
       simp only [bind, Except.bind] at hv
       refine ⟨f.allocas.map (.live · false), fun o ho => ?_,
         by simp only [Step.withMem, Mem.foldl_setLive_run], ?_⟩
       · obtain ⟨b, hb, rfl⟩ := List.mem_map.1 ho
         exact Or.inr ⟨f, List.mem_cons_self, hb⟩
       simp only [step, bind, Except.bind, pure, Except.pure, Step.withMem, Mem.foldl_setLive_run,
         ↓reduceDIte, *])
    | (refine ⟨[], List.forall_mem_nil _, rfl, ?_⟩
       simp only [step, bind, Except.bind, pure, Except.pure, Step.withMem, Mem.run, List.foldl,
         ↓reduceDIte, *])

/-- **The frame lemma for faults.** Under `step_agree`'s hypotheses, a step of the thread on `m₁`
that faults faults on `m₂`. -/
theorem step_fault {c : Ctx} {t : Thread} {m₁ m₂ : Mem} {x : Fault}
    (hs : ∀ f, t.frames.head? = some f → (c.scope m₁ f t.k).NamesIn S)
    (hk : S (m₁.fresh c.who.thread t.k)) (h : m₁.Agree c.who S (t.pending c m₁) m₂)
    (he : step c t m₁ = .error x) : ∃ y, step c t m₂ = .error y := by
  cases e : step c t m₂ with
  | error y => exact ⟨y, rfl⟩
  | ok r =>
    have hs' : ∀ f, t.frames.head? = some f → (c.scope m₂ f t.k).NamesIn S := fun f hf =>
      ⟨(hs f hf).null, (hs f hf).regs, (hs f hf).globals⟩
    have hp := Thread.pending_shape h.sameShape hs
    have hk' : S (m₂.next + Nat.pair c.who.thread t.k) := h.next ▸ hk
    obtain ⟨_, _, _, e'⟩ := step_agree hs' hk' (hp ▸ h.symm) e
    rw [he] at e'
    cases e'

end Exec

section Changes

/-- **The disjointness argument for memories.** If `m'` is `m` changed as a step may change it
(`Mem.Changes L N`), with events `d` in front of its trace, then `m` and `m'` agree for thread `w`
at `S` and the reads of `P` if `N` has no number of `S`, no block of `m` at a number of `S` and
`L` admits `w`, and no access of `d` writes a byte that a read of `P` reads in a block of `S` that
admits `w`. -/
theorem Mem.Changes.agree {L N : Nat → Prop} {m m' : Mem} {w : Who} {P : List Event}
    (h : m.Changes L N m') (hN : ∀ b, S b → ¬ N b)
    (hL : ∀ b x, S b → L b → m.blocks b = some x → x.owner.admits w = false)
    (hd : ∀ d, m'.trace = d ++ m.trace → ∀ b x i a, S b → m.blocks b = some x →
      x.owner.admits w = true → Reads P b i → .access a ∈ d → ¬ a.Writes b i) :
    m.Agree w S P m' := by
  obtain ⟨d, ht, ho⟩ := h.old
  refine ⟨h.keeps.next.symm, fun b hb => ?_⟩
  cases hx : m.blocks b with
  | none =>
    cases hx' : m'.blocks b with
    | none => exact .none
    | some _ => exact absurd (h.new b hx (by simp [hx'])) (hN b hb)
  | some x =>
    obtain ⟨x', hx', hr, hw, hl⟩ := ho b x hx
    have hs := h.keeps.blocks b x hx
    rw [hx'] at hs ⊢
    refine .some ⟨(Option.some.inj hs).symm, hr.symm, hw.symm, fun ha => ?_, fun ha i hi => ?_⟩
    all_goals rcases hl with hl | ⟨hv, hbs⟩
    all_goals try simp [hL b x hb hl hx] at ha
    · exact hv.symm
    · rcases hbs i with e | ⟨-, a, ha', hwr⟩
      · exact e.symm
      · exact absurd hwr (hd d ht b x i a hb hx ha hi ha')

end Changes

end MojoProof.Sem
