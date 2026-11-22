import MojoProof.Sem.Trace
import MojoProof.Sem.Rmw

/-!
# Schedule independence: lemmas of T2

Lemmas of T2 (docs/proofs/schedule.md), for every trace, statement, thread, grid, operation and
width. T2 itself is not proved here.

**Traces up to the order of independent events (`Trace.Same`).** Two traces are the same when
`phases` gives them the same accesses, each in the same phase, up to order, and the same number of
barriers of each block of threads. Proved: putting the same events in front keeps two traces the
same (`Trace.Same.append`, the first half of L11); two lists of events each independent of the other
(no barrier of the block of threads of an access of the other, `Event.indep`) give the same trace in
either order (`Trace.Same.swap`, the second half); and the same traces are both racy or both not
(`Trace.Same.racy`, L12, by `racy_iff`) and both keep the promise of `!invariant.load` or both break
it (`Trace.Same.kept`, L12). And a race of one thread's accesses in front of a trace stays a race
when events with no barrier of its block of threads come between (`racy_insert`, L13). `Trace.Same`
is an equivalence (`refl`, `symm`, `trans`), and so is `Grid.Same`, the equivalence of T2: the
same threads, blocks and next block number, and traces that are the same. Instance and twin:
MojoProofTest/Same.lean.

**Pending accesses (L1a for steps).** `Thread.pending c t m` lists the accesses that the step of
thread `t` on memory `m` would log, newest first: for a `load`, `store` or `atomicrmw` at its
position whose pointer operand evaluates to a pointer, its access (two for an `atomicrmw`), and
none otherwise (`Stmt.pending`). For every context, thread and memory, a step that succeeds puts
exactly these accesses in front of the trace, and a step that stops at a collective has none
(`step_pending`, from `exec_pending` for every statement; a store logs its type's store size,
`Mem.store_trace`, by `Layout.encode_length`). For every grid, when thread `n` takes a step
(`Grid.advance`) it is running and the new trace is its pending accesses in front of the old one
(`Grid.advance_pending`). When a collective call completes (`Grid.fire`), thread `n` waited at
it, and a barrier logs one `.barrier` of `n`'s block of threads and any other collective nothing
(`Grid.fire_trace`). Instance and twin, on one launch: MojoProofTest/Eval.lean `pendingTests`.

**No step or fire reads the trace (the rest of L1a).** For every context, statement, scope and
trace `tr`, a statement run on the scope with its trace replaced by `tr` gives the same result,
with `tr` and the statement's pending accesses in front as the trace (`exec_retrace`; the call of
a function, `exec_retrace_call`, has thirteen ways to end and needs twice the default
heartbeats). The same holds for a thread's step (`step_retrace`), a grid's step of thread `n`
(`Grid.advance_retrace`) and the completion of the collective call `n` waits at
(`Grid.fire_retrace`, with the `.barrier` it logs, `Grid.fired`). Hence, for every launch and
context map, grids that are the same have steps that are the same (`Grid.Same.step`, bisim of
schedule.md) and both fault or neither (`Grid.Same.faults`, the fault part of bad_eqv): a grid
the same as `g` is `g` with its trace replaced (`Grid.Same.eq_retrace`), and `Trace.Same.append`
keeps the new traces the same. Instances and twins on grids of one thread:
MojoProofTest/Pending.lean.

**Pending accesses read only the shape of the named blocks (L1c).** For every context, thread,
set `S` of block numbers and memories `m`, `m'` whose blocks at the numbers of `S` have the same
existence, space, size and addresses (`Mem.SameShape`, `Block.shape`), if the scope of the
thread's innermost frame names only numbers of `S` (`Scope.NamesIn`: null's, every pointer in a
register, `Val.NamesIn`, and every global's), its pending accesses on `m` and `m'` are the same
(`Thread.pending_shape`, from `Stmt.pending_shape` and `evalV_shape`, which also says that the
value names only numbers of `S`). The bytes, liveness, read-only flags and owners of blocks, and
blocks at numbers outside `S`, are not read. Instance and twins: MojoProofTest/Pending.lean.

**Reachable grids keep every block (W5's block part) and add none below `next` (C1's part).** For
every memory, `Mem.setLive`, `Mem.log`, a successful `Mem.write` and `Mem.store`, and `Mem.alloc`
at a number from `next` on with no block keep every block that exists, at its number and with its
shape, keep `next`, and add no block below it (`Mem.Keeps`; `Mem.setLive_keeps`, `Mem.log_keeps`,
`Mem.write_keeps`, `Mem.store_keeps`, `Mem.alloc_keeps`); so do every intrinsic that completes
(`intrinsic_keeps`), every statement that continues (`exec_keeps`: an `alloca` at a number in use is
refused, and `Mem.fresh` is at least `next`), every step that continues or returns (`step_keeps`),
and every step and fire of a grid (`Grid.advance_keeps`; `Grid.fire_keeps`, as a fire changes no
block and keeps `next`, `Grid.fire_blocks`). For every launch and context map, every grid
reachable from `g` keeps every block of `g`, its `next`, and every number below `next` with no
block free (`Grid.reach_keeps`). Two memories one of which keeps the other have the same shape at
every number of `S` if every number of `S` with no block is below `next` (`Mem.Keeps.sameShape`).
W5's other part (a waiting thread is at its collective call) and C1's other part (every number a
thread names has a block or is below `next`, the closed-grid invariant) are in
MojoProof/Sem/Closed.lean.

The value part of L10 (two `atomicrmw`s of one admitted operation give the same value in
either order) is in MojoProof/Sem/Rmw.lean, which this module imports, so a file that imports this
module has those declarations too.
-/

namespace MojoProof.Sem

open LLVM

/-- Traces `tr` and `tr'` (newest first) are the same up to the order of independent events:
`phases` lists the same accesses, each in the same phase, up to order, and counts the same number
of barriers of each block of threads. -/
def Trace.Same (tr tr' : List Event) : Prop :=
  (phases tr).1.Perm (phases tr').1 ∧ ∀ k, (phases tr).2.getD k 0 = (phases tr').2.getD k 0

/-- **L11, first half.** The same events in front of two traces that are the same give traces
that are the same. -/
theorem Trace.Same.append {tr tr' : List Event} (h : Trace.Same tr tr') :
    ∀ E : List Event, Trace.Same (E ++ tr) (E ++ tr')
  | [] => h
  | .barrier k :: E => by
    have ih := h.append E
    simp only [List.cons_append, Trace.Same, phases_barrier]
    refine ⟨ih.1, fun j => ?_⟩
    rw [Std.HashMap.getD_insert, Std.HashMap.getD_insert, ih.2 k, ih.2 j]
  | .access a :: E => by
    have ih := h.append E
    simp only [List.cons_append, Trace.Same, phases_access]
    rw [ih.2 a.who.cta]
    exact ⟨ih.1.cons _, ih.2⟩

/-- Every trace is the same as itself. -/
theorem Trace.Same.refl (tr : List Event) : Trace.Same tr tr := ⟨.refl _, fun _ => rfl⟩

/-- `Trace.Same` is transitive. -/
theorem Trace.Same.trans {tr tr' tr'' : List Event} (h : Trace.Same tr tr')
    (h' : Trace.Same tr' tr'') : Trace.Same tr tr'' :=
  ⟨h.1.trans h'.1, fun k => (h.2 k).trans (h'.2 k)⟩

/-- `Trace.Same` is symmetric. -/
theorem Trace.Same.symm {tr tr' : List Event} (h : Trace.Same tr tr') : Trace.Same tr' tr :=
  ⟨h.1.symm, fun k => (h.2 k).symm⟩

/-- Events `e` and `f` are independent: neither is a barrier of the block of threads of the
other, an access. -/
def Event.indep : Event → Event → Bool
  | .barrier k, .access a | .access a, .barrier k => k != a.who.cta
  | _, _ => true

/-- Two independent events in either order give the same trace. -/
theorem Trace.Same.swap₁ {e f : Event} (h : e.indep f = true) (tr : List Event) :
    Trace.Same (e :: f :: tr) (f :: e :: tr) := by
  cases e <;> cases f <;>
    simp only [Event.indep, bne_iff_ne, ne_eq] at h <;>
    simp only [Trace.Same, phases_access, phases_barrier, Std.HashMap.getD_insert, beq_iff_eq]
  · exact ⟨.swap _ _ _, fun _ => trivial⟩
  · exact ⟨by rw [ite_eq_right h], fun _ => trivial⟩
  · exact ⟨by rw [ite_eq_right h], fun _ => trivial⟩
  · refine ⟨.refl _, fun j => ?_⟩
    split_ifs <;> subst_vars <;> simp_all

/-- **L11, second half.** Two lists of events, each of whose events is independent of each
event of the other, in either order give the same trace. -/
theorem Trace.Same.swap {E F : List Event} (h : ∀ e ∈ E, ∀ f ∈ F, e.indep f = true)
    (tr : List Event) : Trace.Same (E ++ F ++ tr) (F ++ E ++ tr) := by
  induction E with
  | nil => simpa using Trace.Same.refl (F ++ tr)
  | cons e E ih =>
    have past : ∀ (F : List Event), (∀ f ∈ F, e.indep f = true) → ∀ tr,
        Trace.Same (e :: (F ++ tr)) (F ++ e :: tr) := fun F => by
      induction F with
      | nil => exact fun _ _ => .refl _
      | cons f F ihF =>
        intro hF tr
        exact (swap₁ (hF f List.mem_cons_self) _).trans
          ((ihF (fun g hg => hF g (List.mem_cons_of_mem _ hg)) tr).append [f])
    have ih' := (ih fun e' he' => h e' (List.mem_cons_of_mem _ he')).append [e]
    simp only [List.cons_append, List.nil_append, List.append_assoc] at ih' ⊢
    exact ih'.trans (past F (h e List.mem_cons_self) _)

/-- **L12, `racy`.** Traces that are the same are both racy or both not. -/
theorem Trace.Same.racy {tr tr' : List Event} (h : Trace.Same tr tr') : racy tr = racy tr' := by
  rw [Bool.eq_iff_iff, racy_iff, racy_iff]
  exact ⟨fun ⟨x, hx, y, hy, hc⟩ => ⟨x, h.1.subset hx, y, h.1.subset hy, hc⟩,
    fun ⟨x, hx, y, hy, hc⟩ => ⟨x, h.1.symm.subset hx, y, h.1.symm.subset hy, hc⟩⟩

/-- **L12, `kept`.** Traces that are the same both keep the promise of `!invariant.load` or both
break it: they have the same accesses. -/
theorem Trace.Same.kept {tr tr' : List Event} (h : Trace.Same tr tr') : kept tr = kept tr' := by
  have mem {tr tr' : List Event} (h : (phases tr).1.Perm (phases tr').1) {a : Access}
      (ha : Event.access a ∈ tr) : Event.access a ∈ tr' :=
    have ⟨n, hn⟩ := phases_mem ha
    mem_phases (x := (a, n)) (h.subset hn)
  rw [Bool.eq_iff_iff, kept_iff, kept_iff]
  exact ⟨fun k a e ha hi he hw => k a e (mem h.1.symm ha) hi (mem h.1.symm he) hw,
    fun k a e ha hi he hw => k a e (mem h.1 ha) hi (mem h.1 he) hw⟩

/-- A racy trace stays racy when events are added in front. -/
theorem racy_append {tr : List Event} (h : racy tr = true) : ∀ E : List Event, racy (E ++ tr) = true
  | [] => h
  | e :: E => racy_cons e (racy_append h E)

/-- Accesses by `a`'s own thread do not race with `a`: `Access.races` skips them. -/
theorem races_skip {a : Access} {sync : Bool} {tr : List Event} :
    ∀ {X : List Event}, (∀ e ∈ X, ∃ a', e = .access a' ∧ a'.who.thread = a.who.thread) →
      a.races sync (X ++ tr) = a.races sync tr
  | [], _ => rfl
  | e :: X, hX => by
    obtain ⟨a', rfl, ht⟩ := hX e List.mem_cons_self
    simp [Access.races, ht, races_skip fun e he => hX e (List.mem_cons_of_mem _ he)]

/-- An access that races with `tr` still races with it after events that contain no barrier of
its block of threads. -/
theorem races_insert {a : Access} {sync : Bool} {tr : List Event} (h : a.races sync tr = true) :
    ∀ {Q : List Event}, .barrier a.who.cta ∉ Q → a.races sync (Q ++ tr) = true
  | [], _ => h
  | .access _ :: Q, hQ => by
    simp [Access.races, races_insert h fun h' => hQ (List.mem_cons_of_mem _ h')]
  | .barrier k :: Q, hQ => by
    have hk : k ≠ a.who.cta := fun hk => hQ (hk ▸ List.mem_cons_self)
    rw [List.cons_append, Access.races, beq_eq_false_iff_ne.2 hk, Bool.or_false]
    exact races_insert h fun h' => hQ (List.mem_cons_of_mem _ h')

/-- **L13.** A race of trace `tr` with accesses `P` in front, all by one thread of block of threads
`w.cta`, stays a race when events `Q` with no barrier of that block of threads come between: the
race is in `tr`, or one of `P` with one of `tr`, and `Q` orders neither. -/
theorem racy_insert {w : Who} {tr Q : List Event} (hQ : .barrier w.cta ∉ Q) :
    ∀ {P : List Event}, (∀ e ∈ P, ∃ a, e = .access a ∧ a.who = w) → racy (P ++ tr) = true →
      racy (P ++ Q ++ tr) = true
  | [], _, h => by simpa using racy_append h Q
  | e :: P, hP, h => by
    obtain ⟨a, rfl, hw⟩ := hP e List.mem_cons_self
    have hP' : ∀ e ∈ P, ∃ a', e = .access a' ∧ a'.who = w := fun e he =>
      hP e (List.mem_cons_of_mem _ he)
    have skip : ∀ X, a.races false (P ++ X) = a.races false X := fun _ =>
      races_skip fun e he => (hP' e he).imp fun a' ⟨he', hw'⟩ => ⟨he', by rw [hw', hw]⟩
    simp only [List.cons_append, racy, Bool.or_eq_true, List.append_assoc] at h ⊢
    rw [skip] at h ⊢
    rcases h with h | h
    · exact .inl (races_insert h (hw ▸ hQ))
    · exact .inr (by simpa using racy_insert hQ hP' h)

/-- Grids `g` and `g'` are the same up to the order of independent trace events: the same
threads, blocks and next block number, and traces that are the same (`Trace.Same`). The
equivalence of schedule independence (T2 in docs/proofs/schedule.md). -/
def Grid.Same (g g' : Grid) : Prop :=
  g.threads = g'.threads ∧ g.mem.blocks = g'.mem.blocks ∧ g.mem.next = g'.mem.next ∧
    Trace.Same g.mem.trace g'.mem.trace

/-- Every grid is the same as itself. -/
theorem Grid.Same.refl (g : Grid) : g.Same g := ⟨rfl, rfl, rfl, .refl _⟩

/-- `Grid.Same` is symmetric. -/
theorem Grid.Same.symm {g g' : Grid} (h : g.Same g') : g'.Same g :=
  ⟨h.1.symm, h.2.1.symm, h.2.2.1.symm, h.2.2.2.symm⟩

/-- `Grid.Same` is transitive. -/
theorem Grid.Same.trans {g g' g'' : Grid} (h : g.Same g') (h' : g'.Same g'') : g.Same g'' :=
  ⟨h.1.trans h'.1, h.2.1.trans h'.2.1, h.2.2.1.trans h'.2.2.1, h.2.2.2.trans h'.2.2.2⟩

/-- Setting a block live or dead keeps the trace. -/
theorem Mem.setLive_trace (m : Mem) (b : Nat) (live : Bool) :
    (m.setLive b live).trace = m.trace := by
  unfold Mem.setLive; split <;> rfl

/-- Setting a list of blocks live or dead keeps the trace. -/
theorem Mem.foldl_setLive_trace (m : Mem) (bs : List Nat) (live : Bool) :
    (bs.foldl (fun m b => m.setLive b live) m).trace = m.trace := by
  induction bs generalizing m with
  | nil => rfl
  | cons b bs ih => simp [ih, Mem.setLive_trace]

/-- An allocation keeps the trace. -/
theorem Mem.alloc_trace (l : Layout) (m : Mem) (space size align : Nat) (live readOnly : Bool)
    (owner : Owner) (addr gaddr : Nat) (init : List MemByte) (num : Option Nat) :
    (m.alloc l space size align live readOnly owner addr gaddr init num).1.trace = m.trace := by
  unfold Mem.alloc; split <;> rfl

/-- A write of bytes that succeeds keeps the trace (it logs nothing; `Mem.store` logs). -/
theorem Mem.write_trace {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {p : Ptr} {bs : List MemByte}
    {al : Option Nat} (h : m.write l w a p bs al = .ok m') : m'.trace = m.trace := by
  unfold Mem.write at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  split at h
  · cases h
  · split at h
    · cases h
    · cases h; rfl

/-- A store that succeeds logs one write access of `l.stored t` bytes at `p`, by `w`, with the
`atomicrmw` operation `op`, in front of the trace. -/
theorem Mem.store_trace {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val} {p : Ptr}
    {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m') :
    m'.trace = .access ⟨w, p, l.stored t, true, op, false⟩ :: m.trace := by
  unfold Mem.store at h
  cases hbs : l.encode t v with
  | none => simp [hbs] at h
  | some bs =>
    simp only [hbs, bind, Except.bind, pure, Except.pure] at h
    split at h
    · cases h
    · rename_i m₁ hw
      cases h
      simp [Mem.log, Mem.write_trace hw, l.encode_length t v bs hbs]

/-- A call of an intrinsic that succeeds with a value and a memory keeps the trace. -/
theorem intrinsic_trace {c : Ctx} {s : Scope} {fm : FastMath} {i : Intrinsic} {args : List Val}
    {v : Option Val} {m' : Mem} (h : intrinsic c s fm i args = .ok (some (v, m'))) :
    m'.trace = s.mem.trace := by
  unfold intrinsic at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals first | (cases h; done) | (cases h; rfl) | (cases h; exact Mem.setLive_trace ..)

/-- The accesses that statement `st` would log in context `c` with scope `s`, newest first: for a
`load`, `store` or `atomicrmw` whose pointer operand evaluates to a pointer, its access (two for an
`atomicrmw`: its write, in front of its read), and nothing otherwise. -/
def _root_.MojoProof.LLVM.Stmt.pending (c : Ctx) (s : Scope) (st : Stmt) : List Event :=
  let acc (a : Nat) (p : Value) (t : Ty) (write : Bool) (op : Option RmwOp) (inv : Bool) :=
    match evalV s (.ptr a) p >>= Val.addr? with
    | .ok q => [Event.access ⟨c.who, q, c.prog.layout.stored t, write, op, inv⟩]
    | .error _ => []
  match st.inst with
  | .load _ t (.mk (.ptr a) p) _ => acc a p t false none (st.md.any (·.1 == "invariant.load"))
  | .store _ (.mk t _) (.mk (.ptr a) p) _ => acc a p t true none false
  | .atomicrmw _ op (.mk (.ptr a) p) (.mk t _) _ _ _ =>
    acc a p t true (some op) false ++ acc a p t false (some op) false
  | _ => []

/-- L1a for statements: a statement that continues logs exactly its pending accesses, and one
that calls or stops at a collective has none. -/
theorem exec_pending {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {e : Eff}
    (h : exec c s k f st = .ok e) :
    match e with
    | .next _ m' => m'.trace = st.pending c s ++ s.mem.trace
    | .call .. | .wait .. => st.pending c s = [] := by
  unfold exec at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | (simp [LLVM.Stmt.pending, Mem.log, Mem.alloc_trace, bind, Except.bind, *]; done)
    | (have := Mem.store_trace ‹Mem.store _ _ _ _ _ _ _ _ _ = Except.ok _›
       simp [LLVM.Stmt.pending, Mem.log, bind, Except.bind, *])
    | (have := intrinsic_trace ‹intrinsic _ _ _ _ _ = Except.ok (some _)›
       simp [LLVM.Stmt.pending, *])

/-- The accesses that the step of thread `t` on memory `m` would log, newest first: those of the
statement at its position (`Stmt.pending`), and none at a terminator. -/
def Thread.pending (c : Ctx) (t : Thread) (m : Mem) : List Event :=
  match t.frames with
  | f :: _ => match f.fn.blocks.find? (·.label == f.label) with
    | some b => match b.stmts[f.pc]? with
      | some st => st.pending c (c.scope m f t.k)
      | none => []
    | none => []
  | [] => []

/-- L1a for steps: a step that succeeds logs exactly the thread's pending accesses, and a step
that stops at a collective has none. -/
theorem step_pending {c : Ctx} {t : Thread} {m : Mem} {r : Step} (h : step c t m = .ok r) :
    match r with
    | .next _ m' | .done m' => m'.trace = t.pending c m ++ m.trace
    | .wait .. => t.pending c m = [] := by
  unfold step at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | (have := exec_pending ‹exec _ _ _ _ _ = Except.ok _›
       simp_all [Thread.pending, Ctx.scope])
    | simp [Thread.pending, Mem.foldl_setLive_trace, *]

/-- L1a for the grid's steps: when thread `n` of grid `g` takes a step, it is running, and the new
grid's trace is its pending accesses in front of `g`'s. -/
theorem Grid.advance_pending {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.advance c n = .ok (some g')) :
    ∃ t, g.threads[n]? = some (.run t) ∧ g'.mem.trace = t.pending (c n) g.mem ++ g.mem.trace := by
  unfold Grid.advance at h
  split at h
  · rename_i t ht
    refine ⟨t, ht, ?_⟩
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      have := step_pending hr
      split at h <;> cases h <;> simp_all
  · cases h

/-- L1a for fires: a collective call that completes was waited at by thread `n`; at a barrier it
logs one `.barrier` of `n`'s block of threads, and at any other collective nothing. -/
theorem Grid.fire_trace {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.fire L c n = .ok (some g')) :
    ∃ t i args r, g.threads[n]? = some (.wait t i args r) ∧
      g'.mem.trace = (match i with
        | .barrier => [Event.barrier (n / volume L.block)]
        | _ => []) ++ g.mem.trace := by
  unfold Grid.fire at h
  cases hn : g.threads[n]? with
  | none => simp [hn, pure, Except.pure] at h
  | some s =>
    cases s with
    | run t => simp [hn, pure, Except.pure] at h
    | done => simp [hn, pure, Except.pure] at h
    | wait t i args r =>
      refine ⟨t, i, args, r, rfl, ?_⟩
      simp only [hn] at h
      repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
      all_goals cases h
      all_goals simp [Mem.log]

/-- Scope `s` with the trace of its memory replaced by `tr`. -/
def Scope.retrace (s : Scope) (tr : List Event) : Scope :=
  { s with mem := { s.mem with trace := tr } }

/-- Replacing the trace keeps the layout. -/
@[simp] theorem Scope.retrace_layout (s : Scope) (tr : List Event) :
    (s.retrace tr).layout = s.layout := by rfl

/-- Replacing the trace replaces the memory's trace. -/
@[simp] theorem Scope.retrace_mem (s : Scope) (tr : List Event) :
    (s.retrace tr).mem = { s.mem with trace := tr } := by rfl

/-- Replacing the trace keeps the step's oracle numbers. -/
@[simp] theorem Scope.retrace_ch (s : Scope) (tr : List Event) : (s.retrace tr).ch = s.ch := by rfl

mutual
/-- L1a: evaluating a value reads no trace. -/
theorem evalV_retrace (s : Scope) (tr : List Event) (t : Ty) :
    ∀ v : Value, evalV (s.retrace tr) t v = evalV s t v
  | .loc _ | .glob _ | .int _ | .float _ | .null | .undef | .poison | .zero => by
    simp [evalV, Scope.retrace]
  | .vec es | .arr es | .struct es => by simp only [evalV, evalTVs_retrace s tr es]
  | .splat e => by simp only [evalV, evalTV_retrace s tr e]
  | .gep fl src b idx => by simp only [evalV, evalTVs_retrace s tr idx, evalTV_retrace s tr b]; rfl
  | .cast op v ty => by simp only [evalV, evalTV_retrace s tr v]; rfl

/-- Evaluating a typed value reads no trace. -/
theorem evalTV_retrace (s : Scope) (tr : List Event) :
    ∀ v : TValue, evalTV (s.retrace tr) v = evalTV s v
  | .mk t v => by simp only [evalTV, evalV_retrace s tr t v]

/-- Evaluating a list of typed values reads no trace. -/
theorem evalTVs_retrace (s : Scope) (tr : List Event) :
    ∀ vs : List TValue, evalTVs (s.retrace tr) vs = evalTVs s vs
  | [] => rfl
  | e :: es => by simp only [evalTVs, evalTV_retrace s tr e, evalTVs_retrace s tr es]
end

/-! The operations of a statement on memory read no trace: those that change no memory give the
same result on every trace, and those that change it give the same memory with the trace in place,
and the access in front for a store. The first are proved `by rfl`, as are `Scope.retrace_layout`,
`Scope.retrace_mem` and `Scope.retrace_ch`, so that `simp` rewrites with them as theorems and the
proofs that use them cite them (a proof `:= rfl` would make them definitional rewrites, which no
proof term records). -/

/-- A load reads no trace. -/
theorem Mem.load_retrace (l : Layout) (m : Mem) (tr : List Event) w a t p al :
    Mem.load l { m with trace := tr } w a t p al = Mem.load l m w a t p al := by rfl

/-- A `getelementptr` reads no trace. -/
theorem gep_retrace (l : Layout) (m : Mem) (tr : List Event) fl src a idx v :
    gep l { m with trace := tr } fl src a idx v = gep l m fl src a idx v := by rfl

/-- A cast reads no trace. -/
theorem castV_retrace (l : Layout) (m : Mem) (tr : List Event) op s x t ch :
    castV l { m with trace := tr } op s x t ch = castV l m op s x t ch := by rfl

/-- An `icmp` reads no trace. -/
theorem icmpV_retrace (l : Layout) (m : Mem) (tr : List Event) p t x y :
    icmpV l { m with trace := tr } p t x y = icmpV l m p t x y := by rfl

/-- `withAttrs` reads no trace, as a function of the value (for `mapM`, and applied by `simp`). -/
theorem withAttrs_retrace (l : Layout) (m : Mem) (tr : List Event) t attrs :
    withAttrs l { m with trace := tr } t attrs = withAttrs l m t attrs := by rfl

/-- Looking up a pointer's block reads no trace. -/
theorem Mem.block_retrace (m : Mem) (tr : List Event) p :
    Mem.block { m with trace := tr } p = m.block p := by rfl

/-- The number of an `alloca`'s block reads no trace. -/
theorem Mem.fresh_retrace (m : Mem) (tr : List Event) n k :
    Mem.fresh { m with trace := tr } n k = m.fresh n k := by rfl

/-- Logging an event on a memory with trace `tr` puts it in front of `tr`. -/
theorem Mem.log_retrace (m : Mem) (tr : List Event) e :
    Mem.log { m with trace := tr } e = { m.log e with trace := e :: tr } := by rfl

/-- Setting a block live or dead reads no trace and keeps it. -/
theorem Mem.setLive_retrace (m : Mem) (tr : List Event) (b : Nat) (live : Bool) :
    Mem.setLive { m with trace := tr } b live = { m.setLive b live with trace := tr } := by
  unfold Mem.setLive
  cases m.blocks b <;> rfl

/-- Setting a list of blocks live or dead reads no trace and keeps it. -/
theorem Mem.foldl_setLive_retrace (m : Mem) (tr : List Event) (bs : List Nat) (live : Bool) :
    bs.foldl (fun m b => m.setLive b live) { m with trace := tr } =
      { bs.foldl (fun m b => m.setLive b live) m with trace := tr } := by
  induction bs generalizing m with
  | nil => rfl
  | cons b bs ih => simp only [List.foldl, Mem.setLive_retrace, ih]

/-- An allocation reads no trace and keeps it. -/
theorem Mem.alloc_retrace (l : Layout) (m : Mem) (tr : List Event) space size align live readOnly
    owner addr gaddr init num :
    Mem.alloc l { m with trace := tr } space size align live readOnly owner addr gaddr init num =
      ({ (m.alloc l space size align live readOnly owner addr gaddr init num).1 with trace := tr },
        (m.alloc l space size align live readOnly owner addr gaddr init num).2) := by
  unfold Mem.alloc
  cases num <;> rfl

/-- A write of bytes reads no trace and keeps it: the same fault, or the same memory with trace
`tr`. -/
theorem Mem.write_retrace (l : Layout) (m : Mem) (tr : List Event) w a p bs al :
    Mem.write l { m with trace := tr } w a p bs al =
      (Mem.write l m w a p bs al).map fun m' => { m' with trace := tr } := by
  unfold Mem.write
  rw [show Mem.check l { m with trace := tr } w a p bs.length al = Mem.check l m w a p bs.length al
    from rfl]
  simp only [bind, Except.bind, pure, Except.pure]
  cases Mem.check l m w a p bs.length al with
  | error => rfl
  | ok r => cases r; dsimp only; split <;> rfl

/-- A store reads no trace: the same fault, or the same memory with its event in front of `tr`. -/
theorem Mem.store_retrace (l : Layout) (m : Mem) (tr : List Event) w a t v p al op :
    Mem.store l { m with trace := tr } w a t v p al op =
      (Mem.store l m w a t v p al op).map fun m' =>
        { m' with trace := .access ⟨w, p, l.stored t, true, op, false⟩ :: tr } := by
  unfold Mem.store
  cases hbs : l.encode t v with
  | none => rfl
  | some bs =>
    simp only [bind, Except.bind, pure, Except.pure, Mem.write_retrace]
    cases Mem.write l m w a p bs al with
    | error => rfl
    | ok m' => simp [Except.map, Mem.log, l.encode_length t v bs hbs]

/-- L1a: an intrinsic reads no trace and logs nothing. -/
theorem intrinsic_retrace (c : Ctx) (s : Scope) (tr : List Event) (fm : FastMath) (i : Intrinsic)
    (args : List Val) :
    intrinsic c (s.retrace tr) fm i args =
      (intrinsic c s fm i args).map (Option.map fun (v, m') => (v, { m' with trace := tr })) := by
  cases h : intrinsic c s fm i args <;>
  · unfold intrinsic at h ⊢
    repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
    all_goals cases h
    all_goals first
      | rfl
      | simp [Mem.block_retrace, Mem.setLive_retrace, bind, Except.bind, pure, Except.pure,
          Except.map, *]
    all_goals rfl

/-- `ownUndef` reads no trace. -/
theorem ownUndef_retrace (c : Ctx) (s : Scope) (tr : List Event) (i : Intrinsic) (args : List Val) :
    ownUndef c (s.retrace tr) i args = ownUndef c s i args := by
  unfold ownUndef
  rw [intrinsic_retrace]
  rcases intrinsic c s {} i args with _ | _ | ⟨_ | _, _⟩ <;> rfl

/-- Effect `e` with the trace of its memory, if it continues, replaced by `tr`. -/
def Eff.retrace (tr : List Event) : Eff → Eff
  | .next f m => .next f { m with trace := tr }
  | e => e

set_option maxHeartbeats 400000 in
/-- `exec_retrace` for a call of a function. It needs twice the default heartbeats: the call has
thirteen ways to end. -/
theorem exec_retrace_call (c : Ctx) (s : Scope) (tr : List Event) (k : Nat) (f : Frame) res fm ret
    g args md :
    exec c (s.retrace tr) k f ⟨res, .call fm ret (.fn g) args, md⟩ =
      (exec c s k f ⟨res, .call fm ret (.fn g) args, md⟩).map (Eff.retrace tr) := by
  cases h : exec c s k f _ <;>
  · simp only [exec, bind, Except.bind, pure, Except.pure] at h
    simp only [exec, bind, Except.bind, pure, Except.pure]
    repeat' split at h
    all_goals cases h
    all_goals simp only [evalTV_retrace, withAttrs_retrace, intrinsic_retrace, ownUndef_retrace,
      Scope.retrace_mem, Eff.retrace, Except.map, Option.map_some, Option.map_none,
      Bool.false_eq_true, ↓reduceIte, *]
    all_goals rfl

/-- **L1a for statements: no statement reads the trace.** For every context, scope, trace and
statement, `exec` on the scope with trace `tr` gives the same fault or effect as on the scope's
own trace, with the statement's pending accesses in front of `tr` if it continues. -/
theorem exec_retrace (c : Ctx) (s : Scope) (tr : List Event) (k : Nat) (f : Frame) (st : Stmt) :
    exec c (s.retrace tr) k f st = (exec c s k f st).map (Eff.retrace (st.pending c s ++ tr)) := by
  obtain ⟨res, inst, md⟩ := st
  by_cases hc : ∃ fm ret g args, inst = .call fm ret (.fn g) args
  · obtain ⟨fm, ret, g, args, rfl⟩ := hc
    exact exec_retrace_call c s tr k f res fm ret g args md
  -- Destructure the operands and types `exec` matches on, so that `simp` reduces its `match`.
  rcases inst with _ | _ | ⟨_, ⟨_, _⟩⟩ | _ | _ | ⟨_, ⟨_, _⟩, _⟩ | ⟨⟨_, _⟩, ⟨_, _⟩, ⟨_, _⟩⟩ | _ | _ |
    ⟨_, _, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, _⟩ |
    ⟨_, ⟨_, _⟩, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, _⟩ |
    ⟨_, _, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, _⟩ | ⟨⟨_, _⟩, _⟩ | ⟨⟨_, _⟩, ⟨_, _⟩, _⟩ |
    ⟨⟨_, _⟩, _⟩ | ⟨⟨_, _⟩, _, _⟩ | ⟨⟨_, _⟩, _, _⟩ | ⟨_, _, (_ | _), _⟩ |
    ⟨_, _, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, ⟨_, _⟩, _, _, _⟩ <;>
  first
  | exact absurd ⟨_, _, _, _, rfl⟩ hc
  | cases h : exec c s k f _ <;>
    · simp only [exec, bind, Except.bind, pure, Except.pure] at h
      simp only [exec, LLVM.Stmt.pending, bind, Except.bind, pure, Except.pure]
      repeat' split at h
      all_goals cases h
      all_goals simp only [evalV_retrace, evalTV_retrace, evalTVs_retrace, Mem.load_retrace,
        gep_retrace, castV_retrace, icmpV_retrace, Mem.fresh_retrace, Mem.log_retrace,
        Mem.alloc_retrace, Mem.store_retrace, Scope.retrace_mem, Scope.retrace_ch, Eff.retrace,
        Except.map, Bool.false_eq_true, ↓reduceIte, *]
      all_goals rfl

/-- Entering a block reads no trace. -/
theorem enter_retrace (s : Scope) (tr : List Event) (f : Frame) (d : Nat) :
    enter (s.retrace tr) f d = enter s f d := by
  simp only [enter, evalV_retrace]

/-- Step result `r` with the trace of its memory, if it has one, replaced by `tr`. -/
def Step.retrace (tr : List Event) : Step → Step
  | .next t m => .next t { m with trace := tr }
  | .done m => .done { m with trace := tr }
  | r => r

/-- **L1a for steps: no step reads the trace.** For every context, thread, memory and trace, the
step of `t` on `m` with trace `tr` gives the same fault or result as on `m`, with `t`'s pending
accesses in front of `tr`. -/
theorem step_retrace (c : Ctx) (t : Thread) (m : Mem) (tr : List Event) :
    step c t { m with trace := tr } = (step c t m).map (Step.retrace (t.pending c m ++ tr)) := by
  have hs : ∀ f k, c.scope { m with trace := tr } f k = (c.scope m f k).retrace tr :=
    fun _ _ => rfl
  cases h : step c t m <;>
  · unfold step at h
    simp only [step, hs, bind, Except.bind, pure, Except.pure]
    repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
    all_goals cases h
    all_goals first
      | (have := exec_pending ‹exec _ _ _ _ _ = Except.ok _›
         simp only at this
         simp only [exec_retrace, Thread.pending, getElem?_pos, Except.map, Eff.retrace,
           Step.retrace, List.nil_append, ↓reduceDIte, *])
      | simp only [exec_retrace, enter_retrace, evalV_retrace, evalTV_retrace,
          withAttrs_retrace, Scope.retrace_layout, Mem.foldl_setLive_retrace, Thread.pending,
          getElem?_neg, Except.map, Step.retrace, List.nil_append, ↓reduceDIte,
          not_false_eq_true, *]
    all_goals rfl

/-- Grid `g` with its trace replaced by `tr`. -/
def Grid.retrace (g : Grid) (tr : List Event) : Grid := { g with mem := { g.mem with trace := tr } }

/-- Replacing a grid's trace by its own trace gives the grid. -/
theorem Grid.retrace_self (g : Grid) : g.retrace g.mem.trace = g := rfl

/-- The events the step of thread `n` of grid `g` would log, newest first: its pending accesses
if it runs (`Thread.pending`), none otherwise. -/
def Grid.pending (c : Nat → Ctx) (g : Grid) (n : Nat) : List Event :=
  match g.threads[n]? with
  | some (.run t) => t.pending (c n) g.mem
  | _ => []

/-- The events the completion of the collective call thread `n` of grid `g` waits at would log:
one `.barrier` of `n`'s block of threads at a barrier, none otherwise. -/
def Grid.fired (L : Launch) (g : Grid) (n : Nat) : List Event :=
  match g.threads[n]? with
  | some (.wait _ .barrier _ _) => [.barrier (n / volume L.block)]
  | _ => []

/-- **L1a for the grid's steps.** For every grid, trace and thread number, the step of thread `n`
of `g` with trace `tr` gives the same fault, `none` or grid as from `g`, with `n`'s pending
accesses in front of `tr` (`Grid.pending`). -/
theorem Grid.advance_retrace (c : Nat → Ctx) (g : Grid) (tr : List Event) (n : Nat) :
    (g.retrace tr).advance c n =
      (g.advance c n).map (Option.map (·.retrace (g.pending c n ++ tr))) := by
  unfold Grid.advance Grid.pending Grid.retrace
  cases hn : g.threads[n]? with
  | none => rfl
  | some st =>
    cases st with
    | run t =>
      simp only [step_retrace]
      cases hs : step (c n) t g.mem with
      | error => rfl
      | ok r =>
        have hp := step_pending hs
        cases r with
        | wait =>
          simp only at hp
          simp [hp, Except.map, Step.retrace, bind, Except.bind, pure, Except.pure]
        | _ => rfl
    | _ => rfl

/-- **L1a for fires.** For every launch, grid, trace and thread number, the completion of the
collective call thread `n` of `g` with trace `tr` waits at gives the same fault, `none` or grid as
from `g`, with its event in front of `tr` (`Grid.fired`). -/
theorem Grid.fire_retrace (L : Launch) (c : Nat → Ctx) (g : Grid) (tr : List Event) (n : Nat) :
    (g.retrace tr).fire L c n =
      (g.fire L c n).map (Option.map (·.retrace (g.fired L n ++ tr))) := by
  have hr : ∀ l ts ns v,
      resumeAll l { g.mem with trace := tr } ts ns v = resumeAll l g.mem ts ns v :=
    fun _ _ _ _ => rfl
  unfold Grid.fire Grid.fired
  cases hn : g.threads[n]? with
  | none => simp [Grid.retrace, hn, pure, Except.pure, Except.map]
  | some st =>
    cases st with
    | run t => simp [Grid.retrace, hn, pure, Except.pure, Except.map]
    | done => simp [Grid.retrace, hn, pure, Except.pure, Except.map]
    | wait t i args r =>
      cases h : g.fire L c n <;>
      · unfold Grid.fire at h
        simp only [hn] at h
        simp only [Grid.retrace, hn, hr, bind, Except.bind, pure, Except.pure]
        repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
        all_goals cases h
        all_goals simp only [Mem.log_retrace, Except.map, Option.map_some, Option.map_none,
          List.nil_append, List.singleton_append, ↓reduceIte, *]
        all_goals rfl

/-- A grid the same as `g` (`Grid.Same`) is `g` with another trace. -/
theorem Grid.Same.eq_retrace {g g' : Grid} (h : g.Same g') : g' = g.retrace g'.mem.trace := by
  obtain ⟨ts, ⟨bs, nx, tr⟩⟩ := g
  obtain ⟨ts', ⟨bs', nx', tr'⟩⟩ := g'
  obtain ⟨rfl, rfl, rfl, -⟩ := h
  rfl

/-- A grid function `F` that reads no trace and puts events `E` in front of it (`hF`, as
`Grid.advance_retrace` and `Grid.fire_retrace` say of a step and a fire) takes grids that are the
same to the same fault, to `none` together, or to grids that are the same (by L11). -/
theorem Grid.Same.map {F : Grid → Except Fault (Option Grid)} {E : List Event} {g₁ g₂ : Grid}
    (h : g₁.Same g₂)
    (hF : ∀ tr, F (g₁.retrace tr) = (F g₁).map (Option.map (·.retrace (E ++ tr)))) :
    (∀ e, F g₁ = .error e ↔ F g₂ = .error e) ∧ (F g₁ = .ok none ↔ F g₂ = .ok none) ∧
      ∀ g₁', F g₁ = .ok (some g₁') → ∃ g₂', F g₂ = .ok (some g₂') ∧ g₁'.Same g₂' := by
  rw [h.eq_retrace, hF]
  have h₁ := hF g₁.mem.trace
  rw [Grid.retrace_self] at h₁
  refine ⟨fun e => ?_, ?_, fun g₁' hg => ⟨_, by rw [hg]; rfl, ?_⟩⟩
  · cases F g₁ <;> simp [Except.map]
  · cases hx : F g₁ with
    | error => simp [Except.map]
    | ok o => cases o <;> simp [Except.map]
  · rw [hg] at h₁
    have e₁ : g₁' = g₁'.retrace (E ++ g₁.mem.trace) := by simpa [Except.map] using h₁
    refine ⟨rfl, rfl, rfl, ?_⟩
    rw [e₁]
    exact h.2.2.2.append E

/-- **`bisim`** (T2, docs/proofs/schedule.md). For every launch and context map, a step from a
grid has a step from every grid the same as it, to a grid the same as the first step's: the same
thread steps, or the same collective call completes. -/
theorem Grid.Same.step {L : Launch} {c : Nat → Ctx} {g₁ g₂ g₁' : Grid} (h : g₁.Same g₂)
    (hs : Grid.Step L c g₁ g₁') : ∃ g₂', Grid.Step L c g₂ g₂' ∧ g₁'.Same g₂' := by
  obtain ⟨n, hs | hs⟩ := hs
  · obtain ⟨g₂', h₂, h'⟩ :=
      (h.map (F := (·.advance c n)) (Grid.advance_retrace c g₁ · n)).2.2 _ hs
    exact ⟨g₂', ⟨n, .inl h₂⟩, h'⟩
  · obtain ⟨g₂', h₂, h'⟩ :=
      (h.map (F := (·.fire L c n)) (Grid.fire_retrace L c g₁ · n)).2.2 _ hs
    exact ⟨g₂', ⟨n, .inr h₂⟩, h'⟩

/-- The `Faults` part of `bad_eqv` (T2): for every launch and context map, grids that are the
same both fault or both do not. -/
theorem Grid.Same.faults {L : Launch} {c : Nat → Ctx} {g₁ g₂ : Grid} (h : g₁.Same g₂) :
    g₁.Faults L c ↔ g₂.Faults L c := by
  have ha : ∀ n e, g₁.advance c n = .error e ↔ g₂.advance c n = .error e := fun n =>
    (h.map (F := (·.advance c n)) (Grid.advance_retrace c g₁ · n)).1
  have hf : ∀ n e, g₁.fire L c n = .error e ↔ g₂.fire L c n = .error e := fun n =>
    (h.map (F := (·.fire L c n)) (Grid.fire_retrace L c g₁ · n)).1
  simp only [Grid.Faults, ha, hf]

/-- The space, size and addresses of a block: what evaluating an operand reads of it. -/
def Block.shape (b : Block) : Nat × Nat × Nat × Nat := (b.space, b.size, b.addr, b.gaddr)

/-- Memories `m` and `m'` have blocks of the same shape (`Block.shape`), or none, at every block
number of `S`. -/
def Mem.SameShape (S : Nat → Prop) (m m' : Mem) : Prop :=
  ∀ b, S b → (m.blocks b).map Block.shape = (m'.blocks b).map Block.shape

mutual
  /-- Every pointer in value `v` (in vectors and aggregates too) names a block number of `S`. -/
  def Val.NamesIn (S : Nat → Prop) : Val → Prop
    | .ptr p => S p.block
    | .vec xs | .agg xs => Val.AllNamesIn S xs
    | _ => True

  /-- Every pointer in values `xs` names a block number of `S`. -/
  def Val.AllNamesIn (S : Nat → Prop) : List Val → Prop
    | [] => True
    | x :: xs => x.NamesIn S ∧ Val.AllNamesIn S xs
end

section Shape

/-! L1c. The operations of an operand on memory read a block only through a pointer to it and
only at its shape: `Mem.addr`, `gepPtr` (and `gep`, on a value that names `S`), the `ptrtoint` of
`castV`, lane by lane (`lanes_congr`). And no operation makes a pointer to a block it was not
given: `fill` and `Layout.zero` hold only null, a float literal no pointer, and `gep`, `castV`
and `lanes` name only what their operand names. -/

variable {S : Nat → Prop}

/-- `Val.AllNamesIn S xs` holds exactly when every member of `xs` names only numbers of `S`. -/
theorem Val.allNamesIn_iff : ∀ {xs : List Val}, Val.AllNamesIn S xs ↔ ∀ x ∈ xs, x.NamesIn S
  | [] => by simp [Val.AllNamesIn]
  | x :: xs => by simp [Val.AllNamesIn, Val.allNamesIn_iff]

/-- `mapM` of functions that agree on the members of the list. -/
theorem mapM_congr {α β ε : Type} {f g : α → Except ε β} :
    ∀ {xs : List α}, (∀ x ∈ xs, f x = g x) → xs.mapM f = xs.mapM g
  | [], _ => rfl
  | x :: xs, h => by
    simp only [List.mapM_cons, h x List.mem_cons_self,
      mapM_congr fun y hy => h y (List.mem_cons_of_mem x hy)]

/-- Every value `mapM` returns is a result of the function on a member of the list. -/
theorem mapM_mem {α β ε : Type} {f : α → Except ε β} {P : β → Prop} :
    ∀ {xs : List α} {ys : List β}, xs.mapM f = .ok ys → (∀ x ∈ xs, ∀ y, f x = .ok y → P y) →
      ∀ y ∈ ys, P y
  | [], ys, h, _ => by cases h; simp
  | x :: xs, ys, h, hP => by
    simp only [List.mapM_cons, bind, Except.bind, pure, Except.pure] at h
    split at h
    · cases h
    · split at h
      · cases h
      · cases h
        rintro y (_ | ⟨_, hy⟩)
        · exact hP x List.mem_cons_self _ ‹_›
        · exact mapM_mem ‹_› (fun z hz => hP z (List.mem_cons_of_mem x hz)) y hy

/-- Two memories of the same shape on `S` give the same address to a pointer into a block of
`S`. -/
theorem Mem.addr_shape {m m' : Mem} (h : m.SameShape S m') {p : Ptr} (hp : S p.block) (l : Layout)
    (a : Nat) : m.addr l a p = m'.addr l a p := by
  have := h _ hp
  unfold Mem.addr Mem.block
  cases hb : m.blocks p.block <;> cases hb' : m'.blocks p.block <;>
    simp only [hb, hb', Option.map_none, Option.map_some, reduceCtorEq, Option.some.injEq,
      Block.shape, Prod.mk.injEq] at this ⊢
  obtain ⟨h1, -, h3, h4⟩ := this
  simp only [h1, h3, h4]

/-- Two memories of the same shape on `S` give the same `getelementptr` of a pointer into a block
of `S`. -/
theorem gepPtr_shape {m m' : Mem} (h : m.SameShape S m') {p : Ptr} (hp : S p.block) l fl src a
    idx : gepPtr l m fl src a p idx = gepPtr l m' fl src a p idx := by
  have := h _ hp
  unfold gepPtr
  rw [Mem.addr_shape h hp]
  unfold Mem.block
  cases hb : m.blocks p.block <;> cases hb' : m'.blocks p.block <;>
    simp only [hb, hb', Option.map_none, Option.map_some, reduceCtorEq, Option.some.injEq,
      Block.shape, Prod.mk.injEq] at this ⊢
  simp only [this.2.1]

/-- Two memories of the same shape on `S` give the same `getelementptr` of a value that names
only numbers of `S`. -/
theorem gep_shape {m m' : Mem} (h : m.SameShape S m') {x : Val} (hx : x.NamesIn S) l fl src a
    idx : gep l m fl src a idx x = gep l m' fl src a idx x := by
  cases x <;> simp only [gep]
  exact gepPtr_shape h hx ..

/-- Two lane functions that agree on values naming only numbers of `S` give the same `lanes` on
such a value. -/
theorem lanes_congr {F G : Nat → Val → Except Fault Val} (hFG : ∀ i v, v.NamesIn S → F i v = G i v)
    {x : Val} (hx : x.NamesIn S) : lanes F x = lanes G x := by
  cases x
  case vec xs =>
    simp only [lanes]
    rw [mapM_congr (g := fun (v, i) => G i v) fun ⟨v, i⟩ hm =>
      hFG i v (Val.allNamesIn_iff.1 hx v (List.fst_mem_of_mem_zipIdx hm))]
  all_goals exact hFG 0 _ hx

/-- Two memories of the same shape on `S` give the same cast of a value that names only numbers
of `S`. -/
theorem castV_shape {m m' : Mem} (h : m.SameShape S m') {x : Val} (hx : x.NamesIn S) l op s t
    ch : castV l m op s x t ch = castV l m' op s x t ch := by
  unfold castV
  split
  all_goals first
    | rfl
    | refine lanes_congr (fun i v hv => ?_) hx
      cases v
      case ptr p => simp only [Mem.addr_shape h hv]
      all_goals rfl

/-- `poison` and `undef` fill a type with no pointer. -/
theorem fill_namesIn {x : Val} (hx : x.NamesIn S) : ∀ t : Ty, (fill x t).NamesIn S
  | .vec n _ => by
    simp only [fill, Val.NamesIn, Val.allNamesIn_iff, List.mem_replicate]
    rintro _ ⟨_, rfl⟩
    exact hx
  | .arr n t => by
    simp only [fill, Val.NamesIn, Val.allNamesIn_iff, List.mem_replicate]
    rintro _ ⟨_, rfl⟩
    exact fill_namesIn hx t
  | .struct fs => by
    simp only [fill, Val.NamesIn, Val.allNamesIn_iff, List.mem_map]
    rintro _ ⟨t, ht, rfl⟩
    exact fill_namesIn hx t
  | .void | .int _ | .fp _ | .ptr _ | .label | .metadata => by simpa only [fill] using hx

/-- If `mapM f xs` is `some ys` and every result of `f` on a member of `xs` satisfies `P`, every
member of `ys` does. -/
theorem mapM_mem_option {α β : Type} {f : α → Option β} {P : β → Prop} :
    ∀ {xs : List α} {ys : List β}, xs.mapM f = some ys → (∀ x ∈ xs, ∀ y, f x = some y → P y) →
      ∀ y ∈ ys, P y
  | [], ys, h, _ => by cases h; simp
  | x :: xs, ys, h, hP => by
    simp only [List.mapM_cons, bind, Option.bind] at h
    cases hx : f x <;> cases hxs : xs.mapM f <;> simp [hx, hxs] at h
    subst h
    rintro y (_ | ⟨_, hy⟩)
    · exact hP x List.mem_cons_self _ hx
    · exact mapM_mem_option hxs (fun z hz => hP z (List.mem_cons_of_mem x hz)) y hy

/-- A zero value holds no pointer but null. -/
theorem zero_namesIn (h0 : S 0) (l : Layout) : ∀ (t : Ty) {v : Val}, l.zero t = some v → v.NamesIn S
  | .int _, v, h | .fp _, v, h | .ptr _, v, h => by
    simp only [Layout.zero, Option.some.injEq] at h
    subst h
    trivial
  | .vec n t, v, h | .arr n t, v, h => by
    simp only [Layout.zero, Option.map_eq_some_iff] at h
    obtain ⟨z, hz, rfl⟩ := h
    simp only [Val.NamesIn, Val.allNamesIn_iff, List.mem_replicate]
    rintro _ ⟨_, rfl⟩
    exact zero_namesIn h0 l t hz
  | .struct fs, v, h => by
    simp only [Layout.zero, Option.map_eq_some_iff] at h
    obtain ⟨zs, hz, rfl⟩ := h
    exact Val.allNamesIn_iff.2 (mapM_mem_option hz fun t ht _ h => zero_namesIn h0 l t h)
  | .void, v, h | .label, v, h | .metadata, v, h => by simp [Layout.zero] at h

/-- A float literal's value contains no pointer, so it satisfies `Val.NamesIn S` for every `S`. -/
theorem floatLit_namesIn {t : FloatTy} {lit : FloatLit} {v : Val} (h : floatLit t lit = .ok v) :
    v.NamesIn S := by
  simp only [floatLit, floatLit.exactIn, floatLit.near, floatLit.wrong, throw, throwThe,
    MonadExceptOf.throw, pure, Except.pure] at h
  repeat' split at h
  all_goals cases h
  all_goals trivial

/-- If a lane function's results name only numbers of `S` when its operands do, so does `lanes`'s
result. -/
theorem lanes_namesIn {F : Nat → Val → Except Fault Val}
    (hF : ∀ i v w, F i v = .ok w → v.NamesIn S → w.NamesIn S) {x y : Val} (hx : x.NamesIn S)
    (h : lanes F x = .ok y) : y.NamesIn S := by
  cases x
  case vec xs =>
    simp only [lanes, Functor.map, Except.map] at h
    split at h
    · cases h
    · cases h
      refine Val.allNamesIn_iff.2 (mapM_mem ‹_› fun p hm w hw => ?_)
      obtain ⟨v, i⟩ := p
      exact hF i v w hw (Val.allNamesIn_iff.1 hx v (List.fst_mem_of_mem_zipIdx hm))
  all_goals exact hF 0 _ _ h hx

/-- A value made from bits (`ofBitList`) contains no pointer, so it satisfies `Val.NamesIn S` for
every `S`, layout, type and bits. -/
theorem ofBitList_namesIn (l : Layout) (t : Ty) (bs : List (Option Bool)) :
    (ofBitList l t bs).NamesIn S := by
  unfold ofBitList
  split
  · simp only [Val.NamesIn, Val.allNamesIn_iff, List.mem_map]
    rintro _ ⟨i, _, rfl⟩
    unfold ofBitList.scalar
    split <;> trivial
  · unfold ofBitList.scalar
    split <;> trivial

/-- A cast of a value that names only numbers of `S` gives a value that does too. -/
theorem castV_namesIn {m : Mem} {x y : Val} (hx : x.NamesIn S) {l op s t ch}
    (h : castV l m op s x t ch = .ok y) : y.NamesIn S := by
  unfold castV at h
  split at h
  all_goals first
    | (unfold bitcast at h
       simp only [bind, Except.bind, pure, Except.pure] at h
       repeat' split at h
       all_goals cases h
       all_goals first | exact hx | exact ofBitList_namesIn ..)
    | refine lanes_namesIn (fun i v w hw hv => ?_) hx h
      simp only [intCast, floatCast, intToFloat, bind, Except.bind, pure, Except.pure] at hw
      repeat' split at hw
      all_goals cases hw
      all_goals trivial
    | cases h

/-- A `getelementptr` of a value that names only numbers of `S` gives a value that does too. -/
theorem gep_namesIn {m : Mem} {x y : Val} (hx : x.NamesIn S) {l fl src a idx}
    (h : gep l m fl src a idx x = .ok y) : y.NamesIn S := by
  cases x
  case ptr p =>
    simp only [gep, gepPtr, bind, Except.bind, pure, Except.pure] at h
    repeat' split at h
    all_goals cases h
    all_goals trivial
  all_goals simp only [gep, pure, Except.pure] at h
  all_goals cases h
  trivial

/-- Scope `s` names only block numbers of `S`: null's, its registers' and its globals'. -/
structure Scope.NamesIn (S : Nat → Prop) (s : Scope) : Prop where
  /-- Builds `Scope.NamesIn` from its three fields. -/
  mk ::
  /-- The null pointer's number 0 is in `S`. -/
  null : S 0
  /-- Every register's value names only numbers of `S`. -/
  regs : ∀ n v, s.regs n = some v → v.NamesIn S
  /-- Every global's pointer names a number of `S`. -/
  globals : ∀ g p, s.globals g = some p → S p.block

mutual
/-- L1c for values: evaluating a value reads the memory only at the shape of the blocks that the
scope names, and gives a value that names only them. -/
theorem evalV_shape {s : Scope} (hs : s.NamesIn S) {m' : Mem} (h : s.mem.SameShape S m')
    (t : Ty) : ∀ v : Value, evalV { s with mem := m' } t v = evalV s t v ∧
      ∀ x, evalV s t v = .ok x → x.NamesIn S
  | .loc n => ⟨rfl, fun x hx => by
      simp only [evalV] at hx
      split at hx
      · cases hx
        exact hs.regs _ _ ‹_›
      · cases hx⟩
  | .glob g => ⟨rfl, fun x hx => by
      simp only [evalV] at hx
      split at hx
      · cases hx
        exact hs.globals _ _ ‹_›
      · cases hx⟩
  | .int _ => ⟨rfl, fun x hx => by
      simp only [evalV] at hx
      split at hx <;> cases hx
      trivial⟩
  | .float _ => ⟨rfl, fun x hx => by
      simp only [evalV] at hx
      split at hx
      · exact floatLit_namesIn hx
      · cases hx⟩
  | .null => ⟨rfl, fun x hx => by
      cases hx
      exact hs.null⟩
  | .undef => ⟨rfl, fun x hx => by
      cases hx
      exact fill_namesIn (x := .undef) trivial t⟩
  | .poison => ⟨rfl, fun x hx => by
      cases hx
      exact fill_namesIn (x := .poison) trivial t⟩
  | .zero => ⟨rfl, fun x hx => by
      simp only [evalV] at hx
      split at hx
      · cases hx
        exact zero_namesIn hs.null _ _ ‹_›
      · cases hx⟩
  | .vec es | .arr es | .struct es => by
    have ih := evalTVs_shape hs h es
    refine ⟨by simp only [evalV, ih.1], fun x hx => ?_⟩
    simp only [evalV, Functor.map, Except.map] at hx
    split at hx
    · cases hx
    · cases hx
      exact ih.2 _ ‹_›
  | .splat e => by
    have ih := evalTV_shape hs h e
    refine ⟨by simp only [evalV, ih.1], fun x hx => ?_⟩
    simp only [evalV, bind, Except.bind, pure, Except.pure] at hx
    repeat' split at hx
    all_goals cases hx
    simp only [Val.NamesIn, Val.allNamesIn_iff, List.mem_replicate]
    rintro _ ⟨_, rfl⟩
    exact ih.2 _ ‹_›
  | .gep fl src b idx => by
    have ihb := evalTV_shape hs h b
    have ihi := evalTVs_shape hs h idx
    rcases b with ⟨_ | _ | _ | a | _ | _ | _ | _ | _, vb⟩
    case ptr =>
      simp only [evalV, ihb.1, ihi.1, bind, Except.bind]
      refine ⟨?_, fun x hx => ?_⟩
      · cases evalTVs s idx
        · rfl
        · cases hb : evalTV s ⟨.ptr a, vb⟩
          · rfl
          · exact (gep_shape h (ihb.2 _ hb) ..).symm
      · split at hx
        · cases hx
        · split at hx
          · cases hx
          · exact gep_namesIn (ihb.2 _ ‹_›) hx
    all_goals exact ⟨rfl, fun x hx => by cases hx⟩
  | .cast op v ty => by
    have ih := evalTV_shape hs h v
    rcases v with ⟨st, vv⟩
    by_cases hc : op.const
    case neg =>
      simp only [evalV, hc, Bool.false_eq_true, ↓reduceIte]
      exact ⟨trivial, fun x hx => by cases hx⟩
    simp only [evalV, hc, ↓reduceIte, ih.1, bind, Except.bind]
    refine ⟨?_, fun x hx => ?_⟩
    · cases hv : evalTV s ⟨st, vv⟩
      · rfl
      · exact (castV_shape h (ih.2 _ hv) ..).symm
    · split at hx
      · cases hx
      · exact castV_namesIn (ih.2 _ ‹_›) hx

/-- On a scope whose values name only numbers of `S` and a memory of the same shape on `S` as the
scope's: a typed value evaluates on that memory as on the scope's, and its value names only
numbers of `S` (`evalV_shape` for a typed value). -/
theorem evalTV_shape {s : Scope} (hs : s.NamesIn S) {m' : Mem} (h : s.mem.SameShape S m') :
    ∀ v : TValue, evalTV { s with mem := m' } v = evalTV s v ∧
      ∀ x, evalTV s v = .ok x → x.NamesIn S
  | .mk t v => by simpa only [evalTV] using evalV_shape hs h t v

/-- On a scope whose values name only numbers of `S` and a memory of the same shape on `S` as the
scope's: a list of typed values evaluates on that memory as on the scope's, and its values name
only numbers of `S`. -/
theorem evalTVs_shape {s : Scope} (hs : s.NamesIn S) {m' : Mem} (h : s.mem.SameShape S m') :
    ∀ vs : List TValue, evalTVs { s with mem := m' } vs = evalTVs s vs ∧
      ∀ xs, evalTVs s vs = .ok xs → Val.AllNamesIn S xs
  | [] => ⟨rfl, fun xs hx => by
      cases hx
      trivial⟩
  | e :: es => by
    have ih₁ := evalTV_shape hs h e
    have ih₂ := evalTVs_shape hs h es
    refine ⟨by simp only [evalTVs, ih₁.1, ih₂.1], fun xs hx => ?_⟩
    simp only [evalTVs, bind, Except.bind, pure, Except.pure] at hx
    split at hx
    · cases hx
    · split at hx
      · cases hx
      · cases hx
        exact ⟨ih₁.2 _ ‹_›, ih₂.2 _ ‹_›⟩
end

/-- L1c for statements: the pending accesses of a statement read the memory only at the shape of
the blocks that the scope names. -/
theorem Stmt.pending_shape {s : Scope} (hs : s.NamesIn S) {m' : Mem} (h : s.mem.SameShape S m')
    (c : Ctx) (st : Stmt) : st.pending c { s with mem := m' } = st.pending c s := by
  have e : ∀ t v, evalV { s with mem := m' } t v = evalV s t v := fun t v =>
    (evalV_shape hs h t v).1
  simp only [LLVM.Stmt.pending, e]

/-- **L1c.** The pending accesses of thread `t` read the memory only at the existence, space,
size and addresses of the blocks that its innermost frame's scope names. -/
theorem Thread.pending_shape {c : Ctx} {t : Thread} {m m' : Mem} (h : m.SameShape S m')
    (hs : ∀ f, t.frames.head? = some f → (c.scope m f t.k).NamesIn S) :
    t.pending c m' = t.pending c m := by
  rcases ht : t.frames with _ | ⟨f, fs⟩
  · simp only [Thread.pending, ht]
  · have e : ∀ st : Stmt, st.pending c (c.scope m' f t.k) = st.pending c (c.scope m f t.k) :=
      Stmt.pending_shape (hs f (by simp [ht])) h c
    simp only [Thread.pending, ht, e]

end Shape

section Keeps

/-! W5's block part and C1's: each memory operation keeps every block that exists, at its number
and with its shape, keeps `next`, and adds blocks only from `next` on (`Mem.Keeps`; an allocation
does at a number from `next` on with no block), and so do statements, steps, fires and reachable
grids. So a number below `next` with no block gets none, and with the premise that every number of
`S` with no block is below `next` (C1, from the closed-grid invariant), `Mem.Keeps` gives
`Mem.SameShape`, the premise of `Thread.pending_shape` (`Mem.Keeps.sameShape`). -/

/-- `m'` keeps every block of `m` at its number with its shape (`Block.shape`), has the `next` of
`m`, and has a block at a number below `next` only if `m` has one there: W5 and C1 for one memory
operation. -/
structure Mem.Keeps (m m' : Mem) : Prop where
  /-- Builds `Mem.Keeps` from its three fields. -/
  mk ::
  /-- Every block of `m` is in `m'` at its number with its shape. -/
  blocks : ∀ b x, m.blocks b = some x → (m'.blocks b).map Block.shape = some x.shape
  /-- `m'` has the `next` of `m`. -/
  next : m'.next = m.next
  /-- A number below `next` with no block in `m` has none in `m'`. -/
  below : ∀ b, b < m.next → m.blocks b = none → m'.blocks b = none

/-- Every memory keeps itself. -/
theorem Mem.Keeps.refl (m : Mem) : m.Keeps m := ⟨fun _ _ hx => by simp [hx], rfl, fun _ _ h => h⟩

/-- `Mem.Keeps` is transitive. -/
theorem Mem.Keeps.trans {m₁ m₂ m₃ : Mem} (h₁ : m₁.Keeps m₂) (h₂ : m₂.Keeps m₃) : m₁.Keeps m₃ := by
  refine ⟨fun b x hx => ?_, h₂.next.trans h₁.next, fun b hb hn =>
    h₂.below b (h₁.next ▸ hb) (h₁.below b hb hn)⟩
  have h := h₁.blocks b x hx
  rcases hy : m₂.blocks b with _ | y
  · simp [hy] at h
  · simp only [hy, Option.map_some, Option.some.injEq] at h
    rw [h₂.blocks b y hy, h]

/-- Setting block `b` keeps every block if the new block has the shape of the old one, if any,
and `b` has a block or is at least `next`. -/
theorem Mem.set_keeps {m : Mem} {b : Nat} {blk : Block}
    (h : ∀ x, m.blocks b = some x → blk.shape = x.shape) (hb : (m.blocks b).isSome ∨ m.next ≤ b) :
    m.Keeps (m.set b blk) := by
  refine ⟨fun c x hx => ?_, rfl, fun c hc hn => ?_⟩
  · by_cases hc : c = b
    · subst hc
      simp [Mem.set, h x hx]
    · simp [Mem.set, hc, hx]
  · have : c ≠ b := by
      rintro rfl
      simp only [hn, Option.isSome_none, Bool.false_eq_true, false_or] at hb
      omega
    simp [Mem.set, this, hn]

/-- Setting a block live or dead keeps the memory's blocks' shapes. -/
theorem Mem.setLive_keeps (m : Mem) (b : Nat) (live : Bool) : m.Keeps (m.setLive b live) := by
  unfold Mem.setLive
  split
  · rename_i blk hb
    exact Mem.set_keeps (fun x hx => by
      rw [hb] at hx
      cases hx
      rfl) (.inl (by simp [hb]))
  · exact Mem.Keeps.refl m

/-- Logging an event keeps the memory's blocks. -/
theorem Mem.log_keeps (m : Mem) (e : Event) : m.Keeps (m.log e) :=
  ⟨fun _ _ hx => by simp [Mem.log, hx], rfl, fun _ _ h => h⟩

/-- An allocation at a number from `next` on with no block keeps every block. -/
theorem Mem.alloc_keeps (l : Layout) (m : Mem) (space size align : Nat) (live readOnly : Bool)
    (owner : Owner) (addr gaddr : Nat) (init : List MemByte) {b : Nat} (hb : m.next ≤ b)
    (h : m.blocks b = none) :
    m.Keeps (m.alloc l space size align live readOnly owner addr gaddr init (some b)).1 :=
  Mem.set_keeps (fun x hx => by simp_all) (.inr hb)

/-- What a check that succeeds checked (the converse of `Mem.check_ok`): it is of a block of the
memory, which is live, whose owner admits the thread and in which the bytes lie, at an address
that the alignment divides, and its offset is the pointer's. -/
theorem Mem.check_inv {l : Layout} {m : Mem} {w : Who} {a n : Nat} {p : Ptr} {al : Option Nat}
    {b : Block} {o : Nat} (h : m.check l w a p n al = .ok (b, o)) :
    m.blocks p.block = some b ∧ b.live = true ∧ b.owner.admits w = true ∧
      (0 ≤ p.off ∧ p.off + n ≤ b.size) ∧ ∃ ad, m.addr l a p = .ok ad ∧
        (∀ k ∈ al, ad % k = 0) ∧ o = p.off.toNat := by
  cases hb : m.blocks p.block with
  | none => simp [Mem.check, Mem.block, hb] at h
  | some b' =>
    simp only [Mem.check, Mem.block, hb, bind, Except.bind, pure, Except.pure] at h
    repeat' split at h
    all_goals first | cases ‹throw _ = Except.ok _› | cases h
    all_goals exact ⟨rfl, ‹_›, ‹_›, ‹_›, _, ‹_›, fun k hk => by simp_all, rfl⟩

/-- A check that succeeds is of a block of the memory, whose owner admits the thread. -/
theorem Mem.check_block {l : Layout} {m : Mem} {w : Who} {a n : Nat} {p : Ptr} {al : Option Nat}
    {b : Block} {o : Nat} (h : m.check l w a p n al = .ok (b, o)) :
    m.blocks p.block = some b ∧ b.owner.admits w = true :=
  ⟨(Mem.check_inv h).1, (Mem.check_inv h).2.2.1⟩

/-- A write of bytes that succeeds keeps the memory's blocks' shapes. -/
theorem Mem.write_keeps {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {p : Ptr} {bs : List MemByte}
    {al : Option Nat} (h : m.write l w a p bs al = .ok m') : m.Keeps m' := by
  unfold Mem.write at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  split at h
  · cases h
  · rename_i r hc
    split at h
    · cases h
    · cases h
      exact Mem.set_keeps (fun x hx => by
        rw [(Mem.check_block hc).1] at hx
        cases hx
        rfl) (.inl (by simp [(Mem.check_block hc).1]))

/-- A store that succeeds keeps the memory's blocks' shapes. -/
theorem Mem.store_keeps {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val} {p : Ptr}
    {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m') :
    m.Keeps m' := by
  unfold Mem.store at h
  cases hbs : l.encode t v with
  | none => simp [hbs] at h
  | some bs =>
    simp only [hbs, bind, Except.bind, pure, Except.pure] at h
    split at h
    · cases h
    · rename_i m₁ hw
      cases h
      exact (Mem.write_keeps hw).trans (Mem.log_keeps _ _)

/-- A memory that keeps every block of `m` has the same shape as `m` at every number of `S` if
every number of `S` with no block in `m` is below `next` (C1). -/
theorem Mem.Keeps.sameShape {S : Nat → Prop} {m m' : Mem} (h : m.Keeps m')
    (hS : ∀ b, S b → m.blocks b = none → b < m.next) : m.SameShape S m' := by
  intro b hb
  cases hx : m.blocks b with
  | none => rw [h.below b (hS b hb hx) hx]
  | some x => rw [h.blocks b x hx]; rfl

/-- Setting a list of blocks live or dead keeps the memory's blocks' shapes. -/
theorem Mem.foldl_setLive_keeps (m : Mem) (bs : List Nat) (live : Bool) :
    m.Keeps (bs.foldl (fun m b => m.setLive b live) m) := by
  induction bs generalizing m with
  | nil => exact Mem.Keeps.refl m
  | cons b bs ih => exact (Mem.setLive_keeps m b live).trans (ih _)

/-- An intrinsic that completes keeps every block. -/
theorem intrinsic_keeps {c : Ctx} {s : Scope} {fm : FastMath} {i : Intrinsic} {args : List Val}
    {v : Option Val} {m' : Mem} (h : intrinsic c s fm i args = .ok (some (v, m'))) :
    s.mem.Keeps m' := by
  unfold intrinsic at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals first | (cases h; done) | (cases h; exact Mem.Keeps.refl _) |
    (cases h; exact Mem.setLive_keeps _ _ _)

/-- W5 for statements: a statement that continues keeps every block. -/
theorem exec_keeps {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {e : Eff}
    (h : exec c s k f st = .ok e) :
    match e with
    | .next _ m' => s.mem.Keeps m'
    | .call .. | .wait .. => True := by
  unfold exec at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals dsimp only
  all_goals first
    | with_reducible exact Mem.Keeps.refl _
    | with_reducible exact Mem.log_keeps _ _
    | with_reducible exact Mem.store_keeps ‹_›
    | with_reducible exact (Mem.log_keeps _ _).trans (Mem.store_keeps ‹_›)
    | with_reducible exact intrinsic_keeps ‹_›
    | (refine Mem.alloc_keeps _ _ _ _ _ _ _ _ _ _ _ ?_ (Option.not_isSome_iff_eq_none.mp ‹_›)
       simp only [Mem.fresh]
       omega)
    | cases ‹throw _ = Except.ok _›

/-- W5 for steps: a step that continues or returns keeps every block. -/
theorem step_keeps {c : Ctx} {t : Thread} {m : Mem} {r : Step} (h : step c t m = .ok r) :
    match r with
    | .next _ m' | .done m' => m.Keeps m'
    | .wait .. => True := by
  unfold step at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | trivial
    | exact Mem.Keeps.refl _
    | exact exec_keeps (e := .next _ _) ‹_›
    | exact Mem.foldl_setLive_keeps _ _ _

/-- W5 for the grid's steps: a step of thread `n` keeps every block. -/
theorem Grid.advance_keeps {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.advance c n = .ok (some g')) : g.mem.Keeps g'.mem := by
  unfold Grid.advance at h
  split at h
  · simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      have := step_keeps hr
      split at h <;> cases h <;> simp_all [Mem.Keeps.refl]
  · cases h

/-- A collective call that completes changes no block and keeps `next`. -/
theorem Grid.fire_blocks {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.fire L c n = .ok (some g')) :
    g'.mem.blocks = g.mem.blocks ∧ g'.mem.next = g.mem.next := by
  unfold Grid.fire at h
  cases hn : g.threads[n]? with
  | none => simp [hn, pure, Except.pure] at h
  | some s =>
    cases s with
    | run t => simp [hn, pure, Except.pure] at h
    | done => simp [hn, pure, Except.pure] at h
    | wait t i args r =>
      simp only [hn] at h
      repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
      all_goals cases h
      all_goals exact ⟨rfl, rfl⟩

/-- W5 for fires: a collective call that completes keeps every block (by `Grid.fire_blocks`). -/
theorem Grid.fire_keeps {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.fire L c n = .ok (some g')) : g.mem.Keeps g'.mem := by
  obtain ⟨hb, hn⟩ := Grid.fire_blocks h
  exact ⟨fun _ _ hx => by simp [hb, hx], hn, fun _ _ h => hb ▸ h⟩

/-- W5's block part and C1's: every grid reachable from `g` keeps every block of `g`, at its number
and with its space, size and addresses, has the `next` of `g`, and has a block below `next` only
where `g` has one. -/
theorem Grid.reach_keeps {L : Launch} {c : Nat → Ctx} {g g' : Grid}
    (h : Relation.ReflTransGen (Grid.Step L c) g g') : g.mem.Keeps g'.mem := by
  induction h with
  | refl => exact Mem.Keeps.refl _
  | tail _ hs ih =>
    obtain ⟨n, hn | hn⟩ := hs
    · exact ih.trans (Grid.advance_keeps hn)
    · exact ih.trans (Grid.fire_keeps hn)

end Keeps

end MojoProof.Sem
