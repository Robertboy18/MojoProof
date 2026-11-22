import MojoProof.Sem.Closed

/-!
# What a step writes

The lemma on what a step writes (L1b of docs/proofs/schedule-owned.md). `Mem.Changes L N m m'`:
`m'` keeps every block of `m` (`Mem.Keeps`: at its number and with its shape; the same `next`; no
new block below `next`) with its read-only flag and owner, adds blocks only at numbers of `N`, and
has the trace of `m` with events `d` in front; a block of `m` at a number outside `L` keeps its
liveness, and its bytes but those that an access of `d` writes (`Access.Writes`). It is reflexive
and transitive (`Mem.Changes.refl`, `Mem.Changes.trans`).

For every context, scope, thread and memory: memory operations (`Mem.log_changes`;
`Mem.setLive_changes` at a number of `L`; `Mem.foldl_setLive_changes`; `Mem.alloc_changes` at a
number of `N` from `next` on with no block; `Mem.store_changes`: a store writes only the bytes of
the access it logs), intrinsics (`intrinsic_changes`: the lifetime markers change only a block the
thread owns, which they check), statements (`exec_changes`) and steps (`step_changes`). A step of
thread `c.who.thread` that continues or returns changes the memory only at the liveness and bytes
of blocks the thread owns or its frames allocated (if `L` has them), at the bytes that its new
trace events write (its pending accesses, by `step_pending`), and by adding the block
`m.fresh c.who.thread t.k` (if `N` has it). `Grid.advance_changes`: the same for the step of thread
`n` of a grid, in context `c n`. `Grid.fire_blocks` (MojoProof/Sem/Schedule.lean): a fire changes
no block and keeps `next`.

The allocas invariant (section Owns). `Grid.Owns c g`: every alloca of a frame of thread `n` of `g`
is a block of `g` that thread `(c n).who.thread` owns (`Mem.Owned`). A step keeps it
(`Grid.advance_owns`: a statement adds to the frame's allocas only the block it allocates, which
is the thread's, `exec_allocas`, `step_allocas`, and a step changes no owner, `Mem.Changes.owned`),
and so does a fire (`Grid.fire_owns`: it changes no block, and a resumed thread has the allocas it
had, `Thread.resume_allocas`); so does every grid reachable from one that has it
(`Grid.reach_owns`), and the grid of `Grid.start` has it, its frames having no allocas
(`Grid.start_owns`). `Grid.start_reach_changes`, for every program, kernel, launch, arguments,
memory, address choice and oracle: in every grid reachable from the start, the step of the running
thread `t` at `n` changes the memory only at the liveness and bytes of the blocks that thread
`(c n).who.thread` owns, at the bytes that its new trace events write, and by adding block
`fresh (c n).who.thread t.k`.
-/

namespace MojoProof.Sem

open LLVM

/-- Access `a` writes byte `i` of block `b`. -/
def Access.Writes (a : Access) (b i : Nat) : Prop :=
  a.write = true ∧ a.ptr.block = b ∧ a.ptr.off ≤ i ∧ (i : Int) < a.ptr.off + a.len

/-- Memory `m'` is `m` changed as a step may change it, at the blocks of `L` and with new blocks
at numbers of `N`: `m'` keeps every block of `m` (`Mem.Keeps`) with its read-only flag and owner,
adds a block only at a number of `N`, and has the trace of `m` with events `d` in front; a block of
`m` at a number outside `L` keeps its liveness, and its bytes but those that the accesses of `d`
write. -/
structure Mem.Changes (L N : Nat → Prop) (m m' : Mem) : Prop where
  /-- The changes from their three parts, `keeps`, `new` and `old`. -/
  mk ::
  /-- `m'` keeps every block of `m` at its number and with its shape, keeps `next`, and has no new
  block below `next`. -/
  keeps : m.Keeps m'
  /-- A number with no block in `m` and a block in `m'` is a number of `N`. -/
  new : ∀ b, m.blocks b = none → (m'.blocks b).isSome → N b
  /-- The trace of `m'` is that of `m` with events `d` in front, and every block of `m` has a block
  of `m'` at its number with the same read-only flag and owner; unless `L` has the number, that
  block has the same liveness and, at every byte, the same byte or one that an access of `d`
  writes. -/
  old : ∃ d, m'.trace = d ++ m.trace ∧ ∀ b x, m.blocks b = some x → ∃ x', m'.blocks b = some x' ∧
    x'.readOnly = x.readOnly ∧ x'.owner = x.owner ∧
    (L b ∨ x'.live = x.live ∧ ∀ i, x'.bytes i = x.bytes i ∨ ∃ a, .access a ∈ d ∧ a.Writes b i)

/-- Every memory is itself changed, for every `L` and `N`. -/
theorem Mem.Changes.refl {L N : Nat → Prop} (m : Mem) : m.Changes L N m :=
  ⟨Mem.Keeps.refl m, fun _ h h' => by simp [h] at h',
    ⟨[], rfl, fun _ x hx => ⟨x, hx, rfl, rfl, .inr ⟨rfl, fun _ => .inl rfl⟩⟩⟩⟩

/-- Changes compose: for the same `L` and `N`, if `m₂` is `m₁` changed and `m₃` is `m₂` changed,
then `m₃` is `m₁` changed. -/
theorem Mem.Changes.trans {L N : Nat → Prop} {m₁ m₂ m₃ : Mem} (h₁ : m₁.Changes L N m₂)
    (h₂ : m₂.Changes L N m₃) : m₁.Changes L N m₃ := by
  obtain ⟨d₁, ht₁, ho₁⟩ := h₁.old
  obtain ⟨d₂, ht₂, ho₂⟩ := h₂.old
  refine ⟨h₁.keeps.trans h₂.keeps, fun b hb h => ?_, d₂ ++ d₁, by rw [ht₂, ht₁, List.append_assoc],
    fun b x hx => ?_⟩
  · cases h₂b : m₂.blocks b with
    | none => exact h₂.new b h₂b h
    | some y => exact h₁.new b hb (by simp [h₂b])
  · obtain ⟨y, hy, hr₁, ho₁, hl₁⟩ := ho₁ b x hx
    obtain ⟨z, hz, hr₂, ho₂, hl₂⟩ := ho₂ b y hy
    refine ⟨z, hz, hr₂.trans hr₁, ho₂.trans ho₁, ?_⟩
    rcases hl₁ with hl | ⟨hv₁, hb₁⟩
    · exact .inl hl
    rcases hl₂ with hl | ⟨hv₂, hb₂⟩
    · exact .inl hl
    refine .inr ⟨hv₂.trans hv₁, fun i => ?_⟩
    rcases hb₂ i with e₂ | ⟨a, ha, hw⟩
    · rcases hb₁ i with e₁ | ⟨a, ha, hw⟩
      · exact .inl (e₂.trans e₁)
      · exact .inr ⟨a, List.mem_append_right _ ha, hw⟩
    · exact .inr ⟨a, List.mem_append_left _ ha, hw⟩

/-- Logging event `e` changes memory `m`, for every `L` and `N`. -/
theorem Mem.log_changes {L N : Nat → Prop} (m : Mem) (e : Event) : m.Changes L N (m.log e) :=
  ⟨Mem.log_keeps m e, fun _ h h' => by simp [Mem.log, h] at h',
    ⟨[e], rfl, fun _ x hx => ⟨x, hx, rfl, rfl, .inr ⟨rfl, fun _ => .inl rfl⟩⟩⟩⟩

/-- Making block `b` live or dead changes it only at its liveness and bytes, for every `N` and
every `L` that has `b`. -/
theorem Mem.setLive_changes {L N : Nat → Prop} (m : Mem) {b : Nat} (live : Bool) (hb : L b) :
    m.Changes L N (m.setLive b live) := by
  refine ⟨Mem.setLive_keeps m b live, fun c hc h => ?_, [], ?_, fun c x hx => ?_⟩
  · unfold Mem.setLive at h
    split at h
    · by_cases e : c = b
      · subst e
        simp_all
      · simp [Mem.set, e, hc] at h
    · simp [hc] at h
  · unfold Mem.setLive
    split <;> rfl
  · unfold Mem.setLive
    split
    · rename_i y hy
      by_cases e : c = b
      · subst e
        rw [hy] at hx
        cases hx
        simp only [Mem.set, ite_true]
        exact ⟨_, rfl, rfl, rfl, .inl hb⟩
      · simp only [Mem.set, e, ite_false]
        exact ⟨x, hx, rfl, rfl, .inr ⟨rfl, fun _ => .inl rfl⟩⟩
    · exact ⟨x, hx, rfl, rfl, .inr ⟨rfl, fun _ => .inl rfl⟩⟩

/-- Making each block of `bs` live or dead in turn changes the memory, for every `N` and every `L`
that has every number of `bs`. -/
theorem Mem.foldl_setLive_changes {L N : Nat → Prop} (m : Mem) {bs : List Nat} (live : Bool)
    (hb : ∀ b ∈ bs, L b) : m.Changes L N (bs.foldl (fun m b => m.setLive b live) m) := by
  induction bs generalizing m with
  | nil => exact Mem.Changes.refl m
  | cons b bs ih =>
    exact (Mem.setLive_changes m live (hb b List.mem_cons_self)).trans
      (ih _ fun b h => hb b (List.mem_cons_of_mem _ h))

/-- An allocation at a number of `N` from `next` on with no block changes no block of `m`. -/
theorem Mem.alloc_changes {L N : Nat → Prop} (l : Layout) (m : Mem) (space size align : Nat)
    (live readOnly : Bool) (owner : Owner) (addr gaddr : Nat) (init : List MemByte) {b : Nat}
    (hN : N b) (hb : m.next ≤ b) (h : m.blocks b = none) :
    m.Changes L N (m.alloc l space size align live readOnly owner addr gaddr init (some b)).1 := by
  refine ⟨Mem.alloc_keeps l m space size align live readOnly owner addr gaddr init hb h,
    fun c hc h' => ?_, [], rfl, fun c x hx => ?_⟩
  · by_cases e : c = b
    · exact e ▸ hN
    · simp [Mem.alloc, Mem.set, e, hc] at h'
  · have e : c ≠ b := by
      rintro rfl
      simp [h] at hx
    simp only [Mem.alloc, Mem.set, e, ite_false]
    exact ⟨x, hx, rfl, rfl, .inr ⟨rfl, fun _ => .inl rfl⟩⟩

/-- A check that succeeds is at an offset of at least 0, which it returns. -/
theorem Mem.check_off {l : Layout} {m : Mem} {w : Who} {a n : Nat} {p : Ptr} {al : Option Nat}
    {b : Block} {o : Nat} (h : m.check l w a p n al = .ok (b, o)) :
    0 ≤ p.off ∧ o = p.off.toNat := by
  cases hb : m.blocks p.block with
  | none => simp [Mem.check, Mem.block, hb] at h
  | some b' =>
    simp only [Mem.check, Mem.block, hb, bind, Except.bind, pure, Except.pure] at h
    repeat' split at h
    all_goals first | cases ‹throw _ = Except.ok _› | (cases h; exact ⟨by omega, rfl⟩) | cases h

/-- A store changes its block only at the bytes it writes, which the access it logs writes. -/
theorem Mem.store_changes {L N : Nat → Prop} {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty}
    {v : Val} {p : Ptr} {al : Option Nat} {op : Option RmwOp}
    (h : m.store l w a t v p al op = .ok m') : m.Changes L N m' := by
  have hk := Mem.store_keeps h
  unfold Mem.store at h
  cases hbs : l.encode t v with
  | none => simp [hbs] at h
  | some bs =>
    simp only [hbs, bind, Except.bind, pure, Except.pure] at h
    split at h
    · cases h
    · rename_i m₁ hw
      cases h
      unfold Mem.write at hw
      simp only [bind, Except.bind, pure, Except.pure] at hw
      split at hw
      · cases hw
      · rename_i r hc
        split at hw
        · cases hw
        · cases hw
          obtain ⟨hp, ho⟩ := Mem.check_off hc
          have hb := (Mem.check_block hc).1
          refine ⟨hk, fun c hc' h' => ?_, [_], rfl, fun c x hx => ?_⟩
          · by_cases e : c = p.block
            · subst e
              simp [hb] at hc'
            · simp [Mem.log, Mem.set, e, hc'] at h'
          · by_cases e : c = p.block
            · subst e
              rw [hb] at hx
              cases hx
              simp only [Mem.log, Mem.set, ite_true]
              refine ⟨_, rfl, rfl, rfl, .inr ⟨rfl, fun i => ?_⟩⟩
              simp only [Block.put]
              split
              · rename_i hi
                refine .inr ⟨_, List.mem_singleton_self _, ?_⟩
                unfold Access.Writes
                dsimp only
                exact ⟨rfl, rfl, by omega, by omega⟩
              · exact .inl rfl
            · simp only [Mem.log, Mem.set, e, ite_false]
              exact ⟨x, hx, rfl, rfl, .inr ⟨rfl, fun _ => .inl rfl⟩⟩

/-- An intrinsic that completes changes only the liveness and bytes of a block the thread owns
(`llvm.lifetime.start` and `.end`, which check the owner). -/
theorem intrinsic_changes {L N : Nat → Prop} {c : Ctx} {s : Scope} {fm : FastMath} {i : Intrinsic}
    {args : List Val} {v : Option Val} {m' : Mem}
    (hL : ∀ b x, s.mem.blocks b = some x → x.owner = .thread c.who.thread → L b)
    (h : intrinsic c s fm i args = .ok (some (v, m'))) : s.mem.Changes L N m' := by
  unfold intrinsic at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals first
    | (cases h; done)
    | (cases h; exact Mem.Changes.refl _)
    | (cases h
       obtain ⟨x, hx, ho⟩ := (Option.any_eq_true _ _).1 ‹_›
       exact Mem.setLive_changes _ _ (hL _ x hx (by simpa using ho)))

/-- What a statement writes: for every context, scope, step count `k`, frame and statement, a
statement that continues changes the memory only at the liveness and bytes of blocks thread
`c.who.thread` owns (if `L` has them), at the bytes it writes, and by the block of an `alloca` at
step `k` (if `N` has its number). -/
theorem exec_changes {L N : Nat → Prop} {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {e : Eff} (hL : ∀ b x, s.mem.blocks b = some x → x.owner = .thread c.who.thread → L b)
    (hN : N (s.mem.fresh c.who.thread k)) (h : exec c s k f st = .ok e) :
    match e with
    | .next _ m' => s.mem.Changes L N m'
    | .call .. | .wait .. => True := by
  unfold exec at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals dsimp only
  all_goals first
    | with_reducible exact Mem.Changes.refl _
    | with_reducible exact Mem.log_changes _ _
    | with_reducible exact Mem.store_changes ‹_›
    | with_reducible exact (Mem.log_changes _ _).trans (Mem.store_changes ‹_›)
    | with_reducible exact intrinsic_changes hL ‹_›
    | (refine Mem.alloc_changes _ _ _ _ _ _ _ _ _ _ _ hN ?_
         (Option.not_isSome_iff_eq_none.mp ‹_›)
       simp only [Mem.fresh]
       omega)
    | cases ‹throw _ = Except.ok _›

/-- What a step writes: for every context, thread and memory, a step that continues or returns
changes the memory only at the liveness and bytes of blocks thread `c.who.thread` owns or a frame
allocated (if `L` has them), at the bytes its pending writes write, and by the block
`m.fresh c.who.thread t.k` (if `N` has it). -/
theorem step_changes {L N : Nat → Prop} {c : Ctx} {t : Thread} {m : Mem} {r : Step}
    (hL : ∀ b x, m.blocks b = some x → x.owner = .thread c.who.thread → L b)
    (hA : ∀ f ∈ t.frames, ∀ b ∈ f.allocas, L b) (hN : N (m.fresh c.who.thread t.k))
    (h : step c t m = .ok r) :
    match r with
    | .next _ m' | .done m' => m.Changes L N m'
    | .wait .. => True := by
  unfold step at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | trivial
    | exact Mem.Changes.refl _
    | exact exec_changes (e := .next _ _) hL hN ‹_›
    | exact Mem.foldl_setLive_changes _ _ (hA _ (by simp [‹t.frames = _›]))

/-- What the grid's step writes: the step of the running thread `t` at `n` changes the memory as
`step_changes` says, in context `c n`. -/
theorem Grid.advance_changes {L N : Nat → Prop} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    {t : Thread} (ht : g.threads[n]? = some (.run t))
    (hL : ∀ b x, g.mem.blocks b = some x → x.owner = .thread (c n).who.thread → L b)
    (hA : ∀ f ∈ t.frames, ∀ b ∈ f.allocas, L b) (hN : N (g.mem.fresh (c n).who.thread t.k))
    (h : g.advance c n = .ok (some g')) : g.mem.Changes L N g'.mem := by
  unfold Grid.advance at h
  rw [ht] at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · rename_i r hr
    have := step_changes hL hA hN hr
    split at h <;> cases h <;> simp_all [Mem.Changes.refl]

section Owns

/-- Thread `w` owns block `b` of `m`. -/
def Mem.Owned (m : Mem) (w b : Nat) : Prop := ∃ x, m.blocks b = some x ∧ x.owner = .thread w

/-- Changes keep owners: a block of `m` that thread `w` owns is a block of `m'` that `w` owns. -/
theorem Mem.Changes.owned {L N : Nat → Prop} {m m' : Mem} (h : m.Changes L N m') {w b : Nat}
    (hb : m.Owned w b) : m'.Owned w b := by
  obtain ⟨x, hx, ho⟩ := hb
  obtain ⟨d, -, hd⟩ := h.old
  obtain ⟨x', hx', -, ho', -⟩ := hd b x hx
  exact ⟨x', hx', ho'.trans ho⟩

/-- Every alloca of a frame of the thread of `s` is a number of `P`. -/
def Status.AllocasIn (P : Nat → Prop) : Status → Prop
  | .run t | .wait t .. => ∀ f ∈ t.frames, ∀ b ∈ f.allocas, P b
  | .done => True

/-- If every alloca of the state's frames is a number of `P`, and `Q` has every number of `P`,
then every such alloca is a number of `Q`. -/
theorem Status.AllocasIn.mono {P Q : Nat → Prop} (h : ∀ b, P b → Q b) :
    ∀ {s : Status}, s.AllocasIn P → s.AllocasIn Q
  | .run _, hs | .wait .., hs => fun f hf b hb => h b (hs f hf b hb)
  | .done, _ => trivial

/-- Every alloca of a frame of thread `n` of `g` is a block of `g` that thread `(c n).who.thread`
owns. -/
def Grid.Owns (c : Nat → Ctx) (g : Grid) : Prop :=
  ∀ (n : Nat) s, g.threads[n]? = some s → s.AllocasIn (g.mem.Owned (c n).who.thread)

/-- A grid with `Grid.Owns`, with its memory changed (`Mem.Changes` with `L` and `N` true of every
number) and thread `n` set to a state whose frames' allocas are blocks of the new memory that thread
`(c n).who.thread` owns, has `Grid.Owns`. -/
theorem Grid.Owns.set {c : Nat → Ctx} {g : Grid} (hg : g.Owns c) {m' : Mem}
    (hm : g.mem.Changes (fun _ => True) (fun _ => True) m') {n : Nat} {s : Status}
    (hs : s.AllocasIn (m'.Owned (c n).who.thread)) :
    ({ threads := g.threads.set! n s, mem := m' } : Grid).Owns c :=
  set!_inv (P := fun j (s : Status) => s.AllocasIn (m'.Owned (c j).who.thread))
    (fun j x hj => (hg j x hj).mono fun _ => hm.owned) hs

/-- Setting a register of a frame (`Frame.set`) keeps its allocas. -/
theorem Frame.set_allocas (f : Frame) (r : Option Nat) (v : Option Val)
    (prod : Option (Val × Val)) : (f.set r v prod).allocas = f.allocas := by
  unfold Frame.set
  split <;> rfl

/-- Entering a block (`enter`, which sets the registers of its `phi`s) keeps the frame's allocas. -/
theorem enter_allocas {s : Scope} {f f' : Frame} {d : Nat} (h : enter s f d = .ok f') :
    f'.allocas = f.allocas := by
  unfold enter at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  split at h
  · split at h
    · cases h
    cases h
    refine foldl_inv (P := fun f' : Frame => f'.allocas = f.allocas) (Q := fun _ => True) ?_ _ f
      (fun _ _ => trivial) rfl
    rintro f' ⟨st, v⟩ _ hf
    exact (Frame.set_allocas _ _ _ _).trans hf
  · cases h

/-- A statement that continues adds to the frame's allocas only a block that the thread owns. -/
theorem exec_allocas {c : Ctx} {s : Scope} {k : Nat} {f f' : Frame} {st : Stmt} {m' : Mem}
    (h : exec c s k f st = .ok (.next f' m')) :
    ∀ b ∈ f'.allocas, b ∈ f.allocas ∨ m'.Owned c.who.thread b := by
  unfold exec at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | exact fun b hb => .inl (by simpa only [Frame.set_allocas] using hb)
    | (intro b hb
       rcases List.mem_cons.1 hb with rfl | hb
       exacts [.inr ⟨_, ite_eq_left rfl, rfl⟩, .inl hb])

/-- If `f` is a frame of `l`, every frame of `rest` is a frame of `l`, and every alloca of `f'` is
one of `f` or a number of `Q`, then every alloca of a frame of `f' :: rest` is an alloca of a
frame of `l` or a number of `Q`. -/
theorem allocas_cons {Q : Nat → Prop} {l rest : List Frame} {f f' : Frame} (hf : f ∈ l)
    (hr : ∀ g ∈ rest, g ∈ l) (h : ∀ b ∈ f'.allocas, b ∈ f.allocas ∨ Q b) :
    ∀ g ∈ f' :: rest, ∀ b ∈ g.allocas, (∃ g ∈ l, b ∈ g.allocas) ∨ Q b := by
  intro g hg b hb
  rcases List.mem_cons.1 hg with rfl | hg
  · exact (h b hb).imp_left fun hb => ⟨f, hf, hb⟩
  · exact .inl ⟨g, hr g hg, hb⟩

/-- A step that continues adds to the allocas of the thread's frames only a block that the
thread owns. -/
theorem step_allocas {c : Ctx} {t : Thread} {m : Mem} {r : Step} (h : step c t m = .ok r) :
    match r with
    | .next t' m' => ∀ f' ∈ t'.frames, ∀ b ∈ f'.allocas,
        (∃ f ∈ t.frames, b ∈ f.allocas) ∨ m'.Owned c.who.thread b
    | .done _ | .wait .. => True := by
  unfold step at h
  rcases hf : t.frames with _ | ⟨f, rest⟩
  · simp only [hf] at h
    cases h
  have h1 : f ∈ f :: rest := List.mem_cons_self
  have h2 : ∀ g ∈ rest, g ∈ f :: rest := fun _ => List.mem_cons_of_mem _
  simp only [hf] at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | trivial
    | exact allocas_cons h1 h2 (exec_allocas ‹_›)
    | exact allocas_cons h1 (fun _ => id) fun b hb => by simp at hb
    | exact allocas_cons h1 h2 fun b hb => .inl (by rwa [enter_allocas ‹_›] at hb)
    | exact allocas_cons (h2 _ List.mem_cons_self) (fun g hg => h2 g (List.mem_cons_of_mem _ hg))
        fun b hb => .inl (by simpa only [Frame.set_allocas] using hb)

/-- Resuming a thread keeps its frames' allocas: if every alloca of a frame of `t` is a number of
`P`, so is every alloca of a frame of `t.resume v`, for every result `v`. -/
theorem Thread.resume_allocas {P : Nat → Prop} {t : Thread}
    (ht : ∀ f ∈ t.frames, ∀ b ∈ f.allocas, P b) (v : Option Val) :
    ∀ f ∈ (t.resume v).frames, ∀ b ∈ f.allocas, P b := by
  unfold Thread.resume
  split
  · rename_i f rest hf
    intro g hg b hb
    rcases List.mem_cons.1 hg with rfl | hg
    · exact ht f (by rw [hf]; exact List.mem_cons_self) b
        (by simpa only [Frame.set_allocas] using hb)
    · exact ht g (by rw [hf]; exact List.mem_cons_of_mem _ hg) b hb
  · exact ht

/-- A step of thread `n` keeps `Grid.Owns`. -/
theorem Grid.advance_owns {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.advance c n = .ok (some g')) (hg : g.Owns c) : g'.Owns c := by
  unfold Grid.advance at h
  split at h
  · rename_i t ht
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      have hc := step_changes (L := fun _ => True) (N := fun _ => True)
        (fun _ _ _ _ => trivial) (fun _ _ _ _ => trivial) trivial hr
      have ha := step_allocas hr
      cases r with
      | next t' m' =>
        cases h
        exact hg.set hc fun f' hf' b hb =>
          (ha f' hf' b hb).elim (fun ⟨f, hf, hb⟩ => hc.owned (hg n _ ht f hf b hb)) id
      | wait i args fn =>
        cases h
        exact hg.set (Mem.Changes.refl _) (hg n (.run t) ht)
      | done m' =>
        cases h
        exact hg.set hc trivial
  · cases h

/-- A fire keeps `Grid.Owns`: it changes no block, and a resumed thread has the frames' allocas
it had. -/
theorem Grid.fire_owns {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.fire L c n = .ok (some g')) (hg : g.Owns c) : g'.Owns c := by
  have e : g'.mem.Owned = g.mem.Owned := by
    funext w b
    simp only [Mem.Owned, (Grid.fire_blocks h).1]
  unfold Grid.Owns at hg ⊢
  rw [e]
  unfold Grid.fire at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | cases ‹throw _ = Except.ok _›
    | exact resumeAll_inv (P := fun j s => s.AllocasIn (g.mem.Owned (c j).who.thread)) ‹_›
        (fun _ _ _ _ _ _ hs _ => Thread.resume_allocas hs _) hg

/-- In every grid reachable from one that satisfies `Grid.Owns`, the allocas of every thread's
frames are blocks it owns. -/
theorem Grid.reach_owns {L : Launch} {c : Nat → Ctx} {g g' : Grid}
    (h : Relation.ReflTransGen (Grid.Step L c) g g') (hg : g.Owns c) : g'.Owns c :=
  Grid.reach_inv (fun _ _ _ => Grid.advance_owns) (fun _ _ _ => Grid.fire_owns) h hg

/-- A thread at the start of a kernel (`Thread.start`) has no alloca in any frame. -/
theorem Thread.start_allocas {fn : Func} {args : List Val} {t : Thread}
    (h : Thread.start fn args = .ok t) : ∀ f ∈ t.frames, ∀ b ∈ f.allocas, False := by
  unfold Thread.start at h
  simp only [pure, Except.pure] at h
  split at h
  · cases h
    simp
  · cases h

/-- The frames of the threads of the grid that `Grid.start` gives have no allocas. -/
theorem Grid.start_owns {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (c' : Nat → Ctx) : g.Owns c' :=
  fun n s hs => by
    obtain ⟨-, _, _, ht, rfl⟩ := Grid.start_run h n s hs
    exact fun f hf b hb => (Thread.start_allocas ht f hf b hb).elim

/-- What a step writes, in every grid reachable from the start, for every program, kernel,
launch, arguments, memory and choices: a step of the running thread `t` at `n` changes the memory
only at the liveness and bytes of the blocks that thread `(c n).who.thread` owns, at the bytes
that its new trace events write, and by adding block `fresh (c n).who.thread t.k`
(`Mem.Changes`). -/
theorem Grid.start_reach_changes {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g₁ g₂ : Grid} {c : Nat → Ctx}
    {n : Nat} {t : Thread} (h : Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hr : Relation.ReflTransGen (Grid.Step L c) g g₁) (ht : g₁.threads[n]? = some (.run t))
    (h₂ : g₁.advance c n = .ok (some g₂)) :
    g₁.mem.Changes (g₁.mem.Owned (c n).who.thread) (· = g₁.mem.fresh (c n).who.thread t.k)
      g₂.mem :=
  Grid.advance_changes ht (fun _ x hx ho => ⟨x, hx, ho⟩)
    (Grid.reach_owns hr (Grid.start_owns h c) n _ ht) rfl h₂

end Owns

end MojoProof.Sem
