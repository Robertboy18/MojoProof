import MojoProofTest.SkelVadd

/-!
# `Kernel.skel_sound` for `vector_addition` at `L23` (six threads)

`vector_addition` launched as `L23` (2 blocks of 3 threads) on `mem5` with buffers at blocks 1, 2,
3 and count 5, at address choice `ch₀`, is sound for the blocks and the trivial relation on every
memory related to `mem5` by `Mem.SkelEq` (`skel_vadd23`). Its `Labels.MemOk` premise
(`memOk23`) comes from `Labels.MemOk.of_threads`, not from a search of the interleavings: every
grid reachable from the start has a memory equal to the start's memory `m₀` but for the bytes of
block 3 (`EqOff 3`), and every thread's status is one of the statuses of its run alone on `m₀`
(`RefStatus`, `walk`). The kernel checks the six runs alone (`check23_ok`): at each step, the
thread's pending reads miss block 3 and stay in bounds (`readsOk`), its `Labels.MemNext` holds
(`memNextB`), and the step changes nothing but the bytes of block 3 and adds no block at its
fresh number (`stepOk`). A step of a thread from a reachable grid then agrees with its step on `m₀`
(`Grid.advance_agree`, `EqOff.agree`), and the same memory changes keep `EqOff` (`EqOff.run`,
`run_none`). The run to the end is `Grid.run` evaluated by the kernel (`runCheck23_ok`).
-/

namespace MojoProofTest.SkelVadd23

open MojoProof MojoProof.Sem MojoProof.LLVM Relation
open MojoProofTest.Kernel (ch₀ ω₀ mem5 L23)
open MojoProofTest.SkelVadd (payV labV memNextB)

unseal Array.anyM.loop

/-! ## Memories equal but for the bytes of one block -/

/-- Blocks `x` and `y` are equal but for their bytes, and, unless `skip`, at every byte below
`x`'s size. -/
def BlockEq (skip : Bool) (x y : Sem.Block) : Prop :=
  x.shape = y.shape ∧ x.readOnly = y.readOnly ∧ x.owner = y.owner ∧ x.live = y.live ∧
    (skip = false → ∀ i < x.size, x.bytes i = y.bytes i)

/-- `BlockEq` is reflexive. -/
theorem BlockEq.refl (skip : Bool) (x : Sem.Block) : BlockEq skip x x :=
  ⟨rfl, rfl, rfl, rfl, fun _ _ _ => rfl⟩

/-- Blocks related by `BlockEq` have the same size. -/
theorem BlockEq.size {skip : Bool} {x y : Sem.Block} (h : BlockEq skip x y) : x.size = y.size :=
  congrArg (fun s : Nat × Nat × Nat × Nat => s.2.1) h.1

/-- `BlockEq` is transitive. -/
theorem BlockEq.trans {skip : Bool} {x y z : Sem.Block} (h₁ : BlockEq skip x y)
    (h₂ : BlockEq skip y z) : BlockEq skip x z :=
  ⟨h₁.1.trans h₂.1, h₁.2.1.trans h₂.2.1, h₁.2.2.1.trans h₂.2.2.1, h₁.2.2.2.1.trans h₂.2.2.2.1,
    fun hs i hi => (h₁.2.2.2.2 hs i hi).trans (h₂.2.2.2.2 hs i (h₁.size ▸ hi))⟩

/-- A put keeps `BlockEq`. -/
theorem BlockEq.put {skip : Bool} {x y : Sem.Block} (h : BlockEq skip x y) (o : Nat)
    (bs : List MemByte) : BlockEq skip (x.put o bs) (y.put o bs) := by
  refine ⟨h.1, h.2.1, h.2.2.1, h.2.2.2.1, fun hs i hi => ?_⟩
  simp only [Sem.Block.put]
  split_ifs
  · rfl
  · exact h.2.2.2.2 hs i hi

/-- Making blocks live or dead keeps `BlockEq`. -/
theorem BlockEq.setLive {skip : Bool} {x y : Sem.Block} (h : BlockEq skip x y) (v : Bool) :
    BlockEq skip { x with live := v, bytes := if v then fun _ => .undef else x.bytes }
      { y with live := v, bytes := if v then fun _ => .undef else y.bytes } := by
  refine ⟨h.1, h.2.1, h.2.2.1, rfl, fun hs i hi => ?_⟩
  cases v
  · exact h.2.2.2.2 hs i hi
  · rfl

/-- Memories `m₁` and `m₂` have the same `next` and, at every number, both no block or blocks
related by `BlockEq`, with the bytes compared at every number but `b₀`. -/
def EqOff (b₀ : Nat) (m₁ m₂ : Mem) : Prop :=
  m₁.next = m₂.next ∧ ∀ b, Option.Rel (BlockEq (b == b₀)) (m₁.blocks b) (m₂.blocks b)

/-- `EqOff` is reflexive. -/
theorem EqOff.refl (b₀ : Nat) (m : Mem) : EqOff b₀ m m := by
  refine ⟨rfl, fun b => ?_⟩
  cases m.blocks b with
  | none => exact .none
  | some x => exact .some (BlockEq.refl _ x)

/-- `EqOff` is transitive. -/
theorem EqOff.trans {b₀ : Nat} {m₁ m₂ m₃ : Mem} (h₁ : EqOff b₀ m₁ m₂) (h₂ : EqOff b₀ m₂ m₃) :
    EqOff b₀ m₁ m₃ := by
  refine ⟨h₁.1.trans h₂.1, fun b => ?_⟩
  have e₁ := h₁.2 b
  have e₂ := h₂.2 b
  revert e₁ e₂
  cases m₁.blocks b <;> cases m₂.blocks b <;> cases m₃.blocks b <;> intro e₁ e₂ <;>
    cases e₁ <;> cases e₂
  · exact .none
  · rename_i hxy hyz
    exact .some (hxy.trans hyz)

/-- One change applied to two memories keeps `EqOff`. -/
theorem EqOff.apply {b₀ : Nat} {m₁ m₂ : Mem} (h : EqOff b₀ m₁ m₂) :
    ∀ op : Mem.Op, EqOff b₀ (m₁.apply op) (m₂.apply op)
  | .put b o bs => by
    have hb := h.2 b
    simp only [Mem.apply]
    revert hb
    cases hx : m₁.blocks b <;> cases hy : m₂.blocks b <;> intro hb <;> cases hb
    · exact h
    · rename_i x y hxy
      refine ⟨h.1, fun c => ?_⟩
      simp only [Mem.set]
      split_ifs with hc
      · subst hc
        exact .some (hxy.put o bs)
      · exact h.2 c
  | .set b x => by
    refine ⟨h.1, fun c => ?_⟩
    simp only [Mem.apply, Mem.set]
    split_ifs
    · exact .some (BlockEq.refl _ x)
    · exact h.2 c
  | .live b v => by
    have hb := h.2 b
    simp only [Mem.apply, Mem.setLive]
    revert hb
    cases hx : m₁.blocks b <;> cases hy : m₂.blocks b <;> intro hb <;> cases hb
    · exact h
    · rename_i x y hxy
      refine ⟨h.1, fun c => ?_⟩
      simp only [Mem.set]
      by_cases hc : c = b
      · subst hc
        simp only [↓reduceIte]
        exact .some (hxy.setLive v)
      · simp only [hc, ↓reduceIte]
        exact h.2 c
  | .log _ => ⟨h.1, h.2⟩

/-- The same changes applied to two memories keep `EqOff`. -/
theorem EqOff.run {b₀ : Nat} {m₁ m₂ : Mem} (h : EqOff b₀ m₁ m₂) (ops : List Mem.Op) :
    EqOff b₀ (m₁.run ops) (m₂.run ops) := by
  induction ops generalizing m₁ m₂ with
  | nil => exact h
  | cons o ops ih => exact ih (h.apply o)

/-- Memories related by `EqOff b₀` agree (`Mem.Agree`) for every thread at every number, at the
reads of `P`, if `P` reads no byte of block `b₀` and only bytes below the sizes of `m₂`'s
blocks. -/
theorem EqOff.agree {b₀ : Nat} {m₁ m₂ : Mem} (h : EqOff b₀ m₁ m₂) {w : Who} {S : Nat → Prop}
    {P : List Event}
    (hP : ∀ b i, Reads P b i → b ≠ b₀ ∧ ∀ y, m₂.blocks b = some y → i < y.size) :
    m₁.Agree w S P m₂ := by
  refine ⟨h.1, fun b _ => ?_⟩
  have hb := h.2 b
  revert hb
  cases hx : m₁.blocks b <;> cases hy : m₂.blocks b <;> intro hb <;> cases hb
  · exact .none
  · rename_i x y hxy
    refine .some ⟨hxy.1, hxy.2.1, hxy.2.2.1, fun _ => hxy.2.2.2.1, fun _ i hi => ?_⟩
    obtain ⟨hb₀, hs⟩ := hP b i hi
    exact hxy.2.2.2.2 (by simpa using hb₀) i (by rw [hxy.size]; exact hs y hy)

/-- `BlockEq` as a Boolean. -/
def blockEqB (skip : Bool) (x y : Sem.Block) : Bool :=
  decide (x.shape = y.shape) && x.readOnly == y.readOnly && decide (x.owner = y.owner) &&
    x.live == y.live && (skip || (List.range x.size).all fun i => decide (x.bytes i = y.bytes i))

/-- What `blockEqB` says: `BlockEq`. -/
theorem blockEqB_sound {skip : Bool} {x y : Sem.Block} (h : blockEqB skip x y = true) :
    BlockEq skip x y := by
  simp only [blockEqB, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq, Bool.or_eq_true,
    List.all_eq_true, List.mem_range] at h
  obtain ⟨⟨⟨⟨h1, h2⟩, h3⟩, h4⟩, h5⟩ := h
  refine ⟨h1, h2, h3, h4, fun hs i hi => ?_⟩
  rcases h5 with h5 | h5
  · simp [hs] at h5
  · exact h5 i hi

/-- `EqOff b₀` at the numbers below `B` as a Boolean. -/
def eqOffB (b₀ B : Nat) (m₁ m₂ : Mem) : Bool :=
  m₁.next == m₂.next && (List.range B).all fun b => match m₁.blocks b, m₂.blocks b with
    | none, none => true
    | some x, some y => blockEqB (b == b₀) x y
    | _, _ => false

/-- What `eqOffB` says, for memories with no block from `B` on: `EqOff`. -/
theorem eqOffB_sound {b₀ B : Nat} {m₁ m₂ : Mem} (h : eqOffB b₀ B m₁ m₂ = true)
    (h₁ : ∀ b, B ≤ b → m₁.blocks b = none) (h₂ : ∀ b, B ≤ b → m₂.blocks b = none) :
    EqOff b₀ m₁ m₂ := by
  simp only [eqOffB, Bool.and_eq_true, beq_iff_eq, List.all_eq_true, List.mem_range] at h
  refine ⟨h.1, fun b => ?_⟩
  by_cases hb : b < B
  · have e := h.2 b hb
    revert e
    cases m₁.blocks b <;> cases m₂.blocks b <;> intro e
    · exact .none
    · cases e
    · cases e
    · exact .some (blockEqB_sound e)
  · rw [h₁ b (by omega), h₂ b (by omega)]
    exact .none

/-- Changes that act where `Mem.Op.At` says, on `m`, add no block at a number with no block in
`m` outside `N`: applied to every memory with no block there, they leave none. -/
theorem run_none {m : Mem} {w : Who} {L N : Nat → Prop} {W : List Event} {b : Nat}
    (hb : m.blocks b = none) (hN : ¬ N b) {ops : List Mem.Op}
    (hA : ∀ o ∈ ops, o.At m w L N W) : ∀ {m' : Mem}, m'.blocks b = none →
      (m'.run ops).blocks b = none := by
  induction ops with
  | nil => exact fun h => h
  | cons o ops ih =>
    intro m' h
    refine ih (fun o' ho' => hA o' (List.mem_cons_of_mem _ ho')) (m' := m'.apply o) ?_
    have hA₀ := hA o (by simp)
    cases o with
    | put b' o bs =>
      simp only [Mem.apply]
      split
      · have hc : b ≠ b' := by
          rintro rfl
          obtain ⟨⟨x, hx, -⟩, -⟩ := hA₀
          rw [hb] at hx
          cases hx
        simp only [Mem.set, hc, ↓reduceIte]
        exact h
      · exact h
    | set b' x =>
      have hc : b ≠ b' := by
        rintro rfl
        exact hN hA₀.1
      simp only [Mem.apply, Mem.set, hc, ↓reduceIte]
      exact h
    | live b' v =>
      simp only [Mem.apply, Mem.setLive]
      split
      · rename_i blk hblk
        have hc : b ≠ b' := by
          rintro rfl
          rw [h] at hblk
          cases hblk
        simp only [Mem.set, hc, ↓reduceIte]
        exact h
      · exact h
    | log e => exact h

/-! ## Each thread's run alone on the start's memory, at `L23` -/

/-- Whether the reads of `P` are outside block 3 and inside the blocks of `m` they read. -/
def readsOk (m : Mem) (P : List Event) : Bool :=
  P.all fun e => match e with
    | .access a => a.write || (a.ptr.block != 3 && match m.blocks a.ptr.block with
      | some x => decide (0 ≤ a.ptr.off ∧ a.ptr.off + a.len ≤ x.size)
      | none => false)
    | _ => true

/-- What `readsOk` says: every byte a read of `P` reads is outside block 3 and below the size of
its block in `m`. -/
theorem readsOk_sound {m : Mem} {P : List Event} (h : readsOk m P = true) :
    ∀ b i, Reads P b i → b ≠ 3 ∧ ∀ y, m.blocks b = some y → i < y.size := by
  rintro b i ⟨a, ha, hw, hb, h₁, h₂⟩
  have e := List.all_eq_true.1 h _ ha
  simp only [hw, Bool.false_or, Bool.and_eq_true, bne_iff_ne, ne_eq] at e
  obtain ⟨h3, hx⟩ := e
  subst hb
  refine ⟨h3, fun y hy => ?_⟩
  rw [hy] at hx
  simp only [decide_eq_true_eq] at hx
  omega

/-- A step of thread `t` under context `c` from memory `m` to memory `m'` changes nothing but
the bytes of block 3 below `m`'s `next` and adds no block at the number `fresh` of the step. -/
def stepOk (c : Ctx) (m : Mem) (t : Thread) (m' : Mem) : Bool :=
  eqOffB 3 m.next m' m && (m'.blocks (m.fresh c.who.thread t.k)).isNone

/-- Thread `t` under context `c` on memory `m` meets `Labels.MemNext` under `labV` with blocks 1
to 3 payload (`memNextB`), and its pending reads pass `readsOk`. -/
def okAt (c : Ctx) (m : Mem) (t : Thread) : Bool :=
  memNextB labV payV c m t && readsOk m (t.pending c m)

/-- Thread `t` under context `c` run alone on memory `m` (every step from `m` itself) returns
within `f` steps, waits nowhere, and passes `okAt` and `stepOk` at every step. -/
def walk (c : Ctx) (m : Mem) : Nat → Thread → Bool
  | 0, _ => false
  | f + 1, t => okAt c m t && match step c t m with
    | .ok (.next t' m') => stepOk c m t m' && walk c m f t'
    | .ok (.done m') => stepOk c m t m'
    | _ => false

/-- Every thread of grid `g` runs and passes `walk` on `g`'s memory within 40 steps. -/
def check23 (g : Grid) (c : Nat → Ctx) : Bool :=
  (List.range g.threads.size).all fun n => match g.threads[n]? with
    | some (.run t) => walk (c n) g.mem 40 t
    | _ => false

/-- A check `p` of the start's grid and contexts of `vector_addition` on `L23` with buffers at
blocks 1, 2, 3 and count 5 on `mem5`, at address choice `ch₀` and oracle `ω₀`; `false` if the
start fails. -/
def atStart23 (p : Grid → (Nat → Ctx) → Bool) : Bool :=
  match Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ with
  | .ok (g, c) => p g c
  | .error _ => false

/-- The check of every thread's run alone passes at `L23`, by kernel evaluation. -/
theorem check23_ok : atStart23 check23 = true := by decide +kernel

/-! ## The start's memory has no block from its `next` on -/

/-- The shared memory of a block of threads keeps `Mem.FreeAbove`. -/
theorem shared_above {l : Layout} {gs : List Global} {dyn c : Nat} {ch : Nat → Nat} {m m' : Mem}
    {tab : List (String × Ptr)} (h : shared l gs dyn c ch m = .ok (m', tab)) (hm : m.FreeAbove) :
    m'.FreeAbove := by
  unfold shared at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · rename_i v hv
    refine foldlM_inv (P := fun r => r.1.FreeAbove) (fun r gi r' hs hr => ?_) _ _ h
      (by obtain ⟨_, ⟨⟩, h⟩ := Sym.allocNext_res hm hv; exact h)
    obtain ⟨m1, acc⟩ := r
    obtain ⟨g, i⟩ := gi
    simp only [pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hs
    split at hs
    · cases hs
    · split at hs
      · split at hs
        · cases hs
        · cases hs
          exact hr
      · split at hs
        · cases hs
        · rename_i v' hv'
          cases hs
          obtain ⟨_, ⟨⟩, h⟩ := Sym.allocNext_res hr hv'
          exact h
      · cases hs

/-- The arguments of a launch keep `Mem.FreeAbove`. -/
theorem launchArgs_above {l : Layout} {m m' : Mem} {n : Nat} {fn : Func} {args vs : List Val}
    {ch : Nat → Nat} (h : launchArgs l m n fn args ch = .ok (m', vs)) (hm : m.FreeAbove) :
    m'.FreeAbove := by
  refine foldlM_inv (P := fun r => r.1.FreeAbove) (fun r pv r' hs hr => ?_) _ _ h hm
  obtain ⟨m1, acc⟩ := r
  obtain ⟨⟨p, v⟩, i⟩ := pv
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hs
  split at hs
  · split at hs
    · split at hs
      · cases hs
      · rename_i v' hv'
        cases hs
        obtain ⟨_, ⟨⟩, h⟩ := Sym.allocNext_res hr hv'
        exact h
    · cases hs
  · split at hs
    · cases hs
    · cases hs
      exact hr

/-- The start keeps `Mem.FreeAbove`: if the caller's memory has no block from its `next` on,
neither has the start grid's memory. -/
theorem start_above {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (hm : m.FreeAbove) :
    g.mem.FreeAbove := by
  unfold Grid.start at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  rename_i v1 h1
  have hm1 := foldlM_inv (P := fun r => r.1.FreeAbove) (fun r k r' hs hr => by
    simp only [pure, Except.pure] at hs
    split at hs
    · cases hs
    · rename_i v hv
      cases hs
      exact shared_above hv hr) _ _ h1 hm
  split at h
  · cases h
  rename_i v2 h2
  have hm2 := foldlM_inv (P := fun r => r.1.FreeAbove) (fun r k r' hs hr => by
    simp only [pure, Except.pure] at hs
    split at hs
    · cases hs
    · rename_i v hv
      split at hs
      · cases hs
      · cases hs
        exact launchArgs_above hv hr) _ _ h2 hm1
  cases h
  exact fun b hb => hm2 b hb

/-! ## `Labels.MemOk` at `L23` -/

/-- A check `p` that `atStart23` passes gives the start's grid and contexts, which `p`
accepts. -/
theorem atStart23_ok {p : Grid → (Nat → Ctx) → Bool} (h : atStart23 p = true) :
    ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c) ∧ p g c = true := by
  unfold atStart23 at h
  split at h
  next g c hs => exact ⟨g, c, hs, h⟩
  next => cases h

/-- `Labels.MemAt` depends on the memory only through the shape of the blocks the scope
names. -/
theorem memAt_shape {lab : Labels} {pay : Nat → Prop} {s : Scope} {fn : Func} {st : Stmt}
    {S : Nat → Prop} (hs : s.NamesIn S) {m' : Mem} (h : s.mem.SameShape S m')
    (hm : lab.MemAt pay s fn st) : lab.MemAt pay { s with mem := m' } fn st := by
  unfold Labels.MemAt at hm ⊢
  split
  · rename_i heq
    simp only [heq] at hm
    intro hr q hq
    exact hm hr q (by rw [← (evalV_shape hs h _ _).1]; exact hq)
  · rename_i heq
    simp only [heq] at hm
    intro hv q hq
    exact hm hv q (by rw [← (evalV_shape hs h _ _).1]; exact hq)
  · rename_i heq
    simp only [heq] at hm
    intro hv q hq
    exact hm hv q (by rw [← (evalV_shape hs h _ _).1]; exact hq)
  · trivial

/-- Thread `n`'s status `s` is a status of its run alone on memory `m` (`walk`): returned, or
running a thread that passes `walk` there within some number of steps. -/
def RefStatus (c : Nat → Ctx) (m : Mem) (n : Nat) (s : Status) : Prop :=
  s = .done ∨ ∃ t f, s = .run t ∧ walk (c n) m f t = true

/-- A running status that `RefStatus` admits passes `walk` within some number of steps. -/
theorem RefStatus.walk {c : Nat → Ctx} {m : Mem} {n : Nat} {t : Thread}
    (h : RefStatus c m n (.run t)) : ∃ f, walk (c n) m (f + 1) t = true := by
  rcases h with h | ⟨t', f, h, hw⟩
  · cases h
  · cases h
    cases f with
    | zero => change false = true at hw; cases hw
    | succ f => exact ⟨f, hw⟩

/-- **`Labels.MemOk` for `vector_addition` on `L23`**: the launch on six threads with buffers at
blocks 1, 2, 3 and count 5 on `mem5`, at `ch₀` and `ω₀`, starts, and every grid its steps reach
meets `Labels.MemAll` under `labV` with blocks 1 to 3 payload. Every reachable grid's memory is
the start's memory `m₀` but for the bytes of block 3 (`EqOff 3`), and every thread's status is
one of its run alone on `m₀` (`RefStatus`, `check23_ok`): a step of thread `n` reads no byte of
block 3, so it agrees with its step on `m₀` (`Grid.advance_agree`), which changes nothing but the
bytes of block 3 (`stepOk`); the same changes keep `EqOff` (`EqOff.run`). -/
theorem memOk23 : ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c) ∧
    labV.MemOk (payV · = true) L23 c g := by
  obtain ⟨g₀, c, hs, hck⟩ := atStart23_ok check23_ok
  refine ⟨g₀, c, hs, ?_⟩
  have hab : g₀.mem.FreeAbove := start_above hs MojoProofTest.Kernel.pre5.closed.above
  have hsc : ∀ (m : Mem) (n : Nat) (t : Thread) fr,
      ((c n).scope m fr t.k).NamesIn (fun _ => True) :=
    fun _ _ _ _ => ⟨trivial, fun _ v _ => Val.namesIn_top v, fun _ _ _ => trivial⟩
  have hshape : ∀ m, EqOff 3 m g₀.mem → g₀.mem.SameShape (fun _ => True) m := fun m hI =>
    (hI.agree (w := ⟨0, 0⟩) (P := []) fun _ _ ⟨_, ha, _⟩ => by cases ha).symm.sameShape
  refine Labels.MemOk.of_threads (fun mem => EqOff 3 mem g₀.mem) (RefStatus c g₀.mem) ?_
    ⟨EqOff.refl _ _, ?_⟩ ?_ ?_
  · rintro n t i args fn (h | ⟨t', f, h, -⟩) <;> cases h
  · intro n s hn
    obtain ⟨hlt, -⟩ := Array.getElem?_eq_some_iff.1 hn
    have e := List.all_eq_true.1 hck n (List.mem_range.2 hlt)
    rw [hn] at e
    cases s with
    | run t => exact .inr ⟨t, 40, rfl, e⟩
    | wait => cases e
    | done => cases e
  · intro g g' n t hI hR ht he
    obtain ⟨f, hw⟩ := (hR n _ ht).walk
    simp only [walk, okAt, Bool.and_eq_true] at hw
    obtain ⟨⟨-, hrd⟩, hw⟩ := hw
    have hP : t.pending (c n) g.mem = t.pending (c n) g₀.mem :=
      Thread.pending_shape (hshape _ hI) (fun fr _ => hsc _ _ _ fr)
    have hA : g.mem.Agree (c n).who (fun _ => True) (t.pending (c n) g.mem) g₀.mem := by
      rw [hP]
      exact hI.agree (readsOk_sound hrd)
    obtain ⟨s, ops, hops, rfl, h₂⟩ := Grid.advance_agree ht (fun fr _ => hsc _ _ _ fr) trivial hA he
    have h₂' := h₂ ⟨g.threads, g₀.mem⟩ ht rfl
    obtain ⟨hlt, -⟩ := Array.getElem?_eq_some_iff.1 ht
    have hfr : g.mem.fresh (c n).who.thread t.k = g₀.mem.fresh (c n).who.thread t.k := by
      simp only [Mem.fresh, hI.1]
    have hm' : ∀ m', stepOk (c n) g₀.mem t m' = true → m' = g₀.mem.run ops →
        EqOff 3 (g.mem.run ops) g₀.mem := by
      intro m' hst e
      simp only [stepOk, Bool.and_eq_true, Option.isNone_iff_eq_none] at hst
      subst e
      refine (hI.run ops).trans (eqOffB_sound hst.1 (fun b hb => ?_) hab)
      by_cases hb' : b = g₀.mem.fresh (c n).who.thread t.k
      · rw [hb']
        exact hst.2
      · have hgb : g.mem.blocks b = none := by
          have := hI.2 b
          rw [hab b hb] at this
          revert this
          cases g.mem.blocks b <;> intro this
          · rfl
          · cases this
        exact run_none hgb (by rw [hfr]; exact hb') hops (hab b hb)
    revert hw h₂'
    simp only [Grid.advance, ht, bind, Except.bind]
    cases hst : step (c n) t g₀.mem with
    | error e => intro hw; simp at hw
    | ok r =>
      cases r with
      | next t' m' =>
        intro hw h₂'
        simp only [Bool.and_eq_true] at hw
        simp only [pure, Except.pure, Except.ok.injEq, Option.some.injEq, Grid.mk.injEq] at h₂'
        have hs' : s = .run t' := by
          have := congrArg (·[n]?) h₂'.1
          simp [Array.set!_eq_setIfInBounds, hlt] at this
          exact this.symm
        subst hs'
        refine ⟨hm' m' hw.1 h₂'.2, fun s hs => ?_⟩
        simp [Array.set!_eq_setIfInBounds, hlt] at hs
        subst hs
        exact .inr ⟨t', f, rfl, hw.2⟩
      | wait i args fn => intro hw; simp at hw
      | done m' =>
        intro hw h₂'
        simp only [pure, Except.pure, Except.ok.injEq, Option.some.injEq, Grid.mk.injEq] at h₂'
        have hs' : s = .done := by
          have := congrArg (·[n]?) h₂'.1
          simp [Array.set!_eq_setIfInBounds, hlt] at this
          exact this.symm
        subst hs'
        refine ⟨hm' m' hw h₂'.2, fun s hs => ?_⟩
        simp [Array.set!_eq_setIfInBounds, hlt] at hs
        exact .inl hs.symm
  · intro g n t hI hR ht
    obtain ⟨f, hw⟩ := (hR n _ ht).walk
    simp only [walk, okAt, Bool.and_eq_true] at hw
    have hnx := MojoProofTest.SkelVadd.memNextB_sound hw.1.1
    intro fr rest b st hf hb hst
    exact memAt_shape (hsc _ _ _ fr) (hshape _ hI) (hnx fr rest b st hf hb hst)

/-! ## The instance of `Kernel.skel_sound` at `L23` -/

/-- The run check at `L23`: the run (fuel 64 a thread, one phase) ends in a grid whose trace is
not racy and keeps `!invariant.load` (the core's `racy` and `kept` at `sig`). -/
def runCheck23 (g : Grid) (c : Nat → Ctx) : Bool :=
  match g.run L23 c 64 1 with
  | .ok z => !GPUProof.racy sig (z.mem.trace.map (Event.toCore L23)).reverse &&
    GPUProof.kept sig (z.mem.trace.map (Event.toCore L23)).reverse
  | .error _ => false

/-- The run check passes at the start at `L23`, by kernel evaluation. -/
theorem runCheck23_ok : atStart23 runCheck23 = true := by decide +kernel

/-- **What the checks give at `L23`**: the launch of `vector_addition` on six threads on `mem5`
at address choice `ch₀` and oracle `ω₀` starts, its grid meets `Labels.MemOk` under `labV` with
blocks 1 to 3 payload (`memOk23`), and it reaches a grid in which every thread has returned
(`runCheck23_ok`, `Grid.run_reach`, `Grid.run_done`) and that is not bad. -/
theorem vadd23Ok : ∃ g c z, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c) ∧
    labV.MemOk (payV · = true) L23 c g ∧ ReflTransGen (Grid.Step L23 c) g z ∧
    GPUProof.Done sig (z, L23, c) ∧
    ¬ GPUProof.Bad sig (z, L23, c) := by
  obtain ⟨g, c, hs, hM⟩ := memOk23
  obtain ⟨g', c', hs', hr⟩ := atStart23_ok runCheck23_ok
  rw [hs] at hs'
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj hs')
  unfold runCheck23 at hr
  split at hr
  next z hz =>
    simp only [Bool.and_eq_true, Bool.not_eq_true'] at hr
    obtain ⟨hrc, hk⟩ := hr
    have hd : GPUProof.Done sig (z, L23, c) := Grid.run_done hz
    have hsz := (Grid.start_reach_size hs (Grid.run_reach hz)).le
    refine ⟨g, c, z, hs, hM, Grid.run_reach hz, hd, ?_⟩
    rintro (hf | hr | hk' | hr)
    · exact done_not_faults hsz hd hf
    · exact nomatch hrc.symm.trans hr
    · exact nomatch hk.symm.trans hk'
    · exact Grid.Done.not_raceEnabled hsz hd hr
  next => cases hr

/-- **The instance of `Kernel.skel_sound` on `vector_addition` at `L23`**: under `labV` with
blocks 1 to 3 payload, for every memory `m₂` related to `mem5` by `Mem.SkelEq`, `vector_addition`
launched on six threads (`L23`) on `m₂` with buffers at blocks 1, 2, 3 and count 5 is sound at
address choice `ch₀` and every oracle, for the blocks and the trivial relation: safe, race free,
keeping `!invariant.load`, making progress, terminating and determinate for the blocks. The
premises: `mem5`'s pointer bytes from `pre5` (`Mem.Closed.bytesIn`), `vadd_ok`, the lookup by
`rfl`, and `vadd23Ok` at `ch₀`. -/
theorem skel_vadd23 {m₂ : Mem} (hm : mem5.SkelEq (payV · = true) m₂) :
    Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) m₂ (fun ch _ => ch = ch₀)
      (fun m => some m.blocks) (fun _ => True) :=
  Kernel.skel_sound (lab := labV) MojoProofTest.Kernel.pre5.closed.bytesIn
    MojoProofTest.Labels.vadd_ok rfl
    (fun ch h => by
      subst h
      obtain ⟨g, c, z, hs, hM, hr, hd, hb⟩ := vadd23Ok
      exact ⟨ω₀, g, c, z, hs, hM, hr, hd, hb⟩)
    hm

end MojoProofTest.SkelVadd23
