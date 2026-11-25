import Mathlib.Data.List.Induction
import Mathlib.Data.List.Forall2
import Mathlib.Data.List.Perm.Subperm

/-!
# Asynchronous copies and their groups (docs/proofs/async-copy.md)

A thread's `cp.async` copies from global to shared memory, its group commits and its group
waits (`wait_group n`; PTX ISA 9.5, sections 9.7.10.28.3.1-3), as a per-thread state and a
transition relation. A copy is pending from its issue and may land at any later step, before or
after it is committed; a commit closes the copies issued since the previous commit into a group
(an empty group when there are none); `wait_group n` may proceed only once every copy of the
groups other than the `n` most recent has landed. A copy lands whole, in one step.

Definitions:
* `AsyncCopy`: one copy, `cp.async.<ca|cg>.shared.global [dst], [src], size, srcSize`;
  `AsyncCopy.land gm sm c`: the shared memory `sm` after `c` lands, reading the global memory `gm`;
  `AsyncCopy.Writes c x`: `c` writes shared byte `x`.
* `AsyncOp`: a copy, a commit or a wait; `Async`: the uncommitted copies, the pending groups
  (oldest first) and the landed copies (in landing order); `Async.unlanded`: the copies not
  landed.
* `Async.Step`: one operation, or one copy landing; `Async.Run s ops t`: `t` is reachable from
  `s` by issuing `ops` in order, with any landings before, between and after them (every
  completion choice).
* `Async.lazy`, `Async.lazyRun`: the completion choice that lands a copy only when a wait needs
  it, oldest group first.
* `Async.committed ops`: the copies of `ops` issued before its last commit, in order;
  `Async.uncommitted ops`: those issued after it.

Proved: `Async.Run.lazy` (the lazy choice is a run, so no statement about every run is vacuous);
`Async.Run.within` (in every run, the copies not landed are those of the lazy run with some
removed, group by group, and every issued copy is landed or not); `Async.lazyRun_init`;
`Async.wait_run` (after `wait_group n`, in every run at most `n` groups are pending and every
copy the lazy run has landed has landed, whatever else landed); `Async.visible` (after
`wait_group 0`, in every run every committed copy has landed); `Async.determined` (a shared byte
that no possibly pending copy writes at the end, and that no copy writes while another possibly
pending copy writes it, has the same value under every completion choice, for every sequence of
operations); `Async.visible_bytes` (after `wait_group 0` the bytes of every committed copy are in
shared memory under every completion choice, when the issued copies' destinations are pairwise
disjoint). That no other access touches a destination or a source while a copy is pending (race
freedom) is the caller's premise: the model reads the global memory `gm` when a copy lands, and no
other thread writes the shared memory.
-/

namespace MojoProof.Sem

open scoped List

/-- One `cp.async.<ca|cg>.shared.global [dst], [src], size, srcSize` (PTX ISA 9.5, section
9.7.10.28.3.1): `size` bytes to the shared address `dst`, of which the first `srcSize` come from
the global address `src` and the rest are zeros; without the `srcSize` operand, `srcSize = size`.
-/
structure AsyncCopy where
  /-- Builds a copy from its addresses and sizes. -/
  mk ::
  /-- The shared destination address. -/
  dst : Nat
  /-- The global source address. -/
  src : Nat
  /-- The number of bytes written (the ISA's `cp-size`). -/
  size : Nat
  /-- The number of bytes read (the ISA's `src-size`). -/
  srcSize : Nat
  deriving DecidableEq, Repr

/-- Copy `c` writes shared byte `x`: `c.dst ≤ x < c.dst + c.size`. -/
abbrev AsyncCopy.Writes (c : AsyncCopy) (x : Nat) : Prop :=
  c.dst ≤ x ∧ x < c.dst + c.size

/-- The shared memory `sm` after copy `c` lands, reading the global memory `gm`: byte
`c.dst + o` for `o < c.size` is `gm (c.src + o)` when `o < c.srcSize` and `0` otherwise; every
other byte is `sm`'s. -/
def AsyncCopy.land (gm sm : Nat → UInt8) (c : AsyncCopy) : Nat → UInt8 := fun x =>
  if c.Writes x then
    if x - c.dst < c.srcSize then gm (c.src + (x - c.dst)) else 0
  else sm x

/-- The destinations of two copies do not overlap. -/
def AsyncCopy.Disjoint (x y : AsyncCopy) : Prop :=
  x.dst + x.size ≤ y.dst ∨ y.dst + y.size ≤ x.dst

/-- One of a thread's operations on its asynchronous copies. -/
inductive AsyncOp
  /-- `cp.async`: the copy `c` is issued. -/
  | copy (c : AsyncCopy)
  /-- `cp.async.commit_group` (PTX ISA 9.5, section 9.7.10.28.3.2). -/
  | commit
  /-- `cp.async.wait_group n` (PTX ISA 9.5, section 9.7.10.28.3.3). -/
  | wait (n : Nat)
  deriving DecidableEq, Repr

/-- The copy an operation issues, if it is one. -/
def AsyncOp.copy? : AsyncOp → Option AsyncCopy
  | .copy c => some c
  | _ => none

/-- Whether an operation is a commit. -/
def AsyncOp.isCommit : AsyncOp → Bool
  | .commit => true
  | _ => false

/-- A thread's asynchronous copies: those issued since the last commit and not landed, the
committed groups not yet waited for (oldest first, each with its copies not landed) and the
copies that have landed (in landing order). -/
structure Async where
  /-- Builds the state from its three lists. -/
  mk ::
  /-- The copies issued since the last commit that have not landed. -/
  pending : List AsyncCopy
  /-- The committed groups not yet waited for, oldest first, each with its copies not landed.
  -/
  groups : List (List AsyncCopy)
  /-- The copies that have landed, in order. -/
  landed : List AsyncCopy
  deriving DecidableEq, Repr

namespace Async

/-- The copies of `ops` issued before its last commit, in order (none without a commit). -/
def committed (ops : List AsyncOp) : List AsyncCopy :=
  (ops.reverse.dropWhile (!·.isCommit)).reverse.filterMap AsyncOp.copy?

/-- The copies of `ops` issued after its last commit, in order (all of them without a commit).
-/
def uncommitted (ops : List AsyncOp) : List AsyncCopy :=
  (ops.reverse.takeWhile (!·.isCommit)).reverse.filterMap AsyncOp.copy?

/-- The state of a thread that has issued no copy. -/
def init : Async := ⟨[], [], []⟩

/-- The copies of `s` that have not landed: the pending groups' copies, oldest group first, then
the uncommitted ones. -/
def unlanded (s : Async) : List AsyncCopy :=
  s.groups.flatten ++ s.pending

/-- One step of a thread's asynchronous copies (the trusted reading of PTX ISA 9.5, sections
9.7.10.28.3.1-3): an operation (`some o`) or a copy landing (`none`). A copy joins the
uncommitted copies; a commit closes them into the newest group (empty if there are none);
`wait_group n` is enabled once the groups other than the `n` most recent are empty (all their
copies landed), and drops them; any copy not landed, committed or not, may land, whole, at any
step. -/
inductive Step : Async → Option AsyncOp → Async → Prop
  /-- `cp.async`: the copy `c` joins the uncommitted copies. -/
  | copy (s : Async) (c : AsyncCopy) :
      Step s (some (.copy c)) { s with pending := s.pending ++ [c] }
  /-- `cp.async.commit_group`: the uncommitted copies become the newest group. -/
  | commit (s : Async) :
      Step s (some .commit) { s with pending := [], groups := s.groups ++ [s.pending] }
  /-- `cp.async.wait_group n`, once every copy of the groups other than the `n` most recent has
  landed: those groups are dropped. -/
  | wait (s : Async) (n : Nat) (h : ∀ g ∈ s.groups.take (s.groups.length - n), g = []) :
      Step s (some (.wait n)) { s with groups := s.groups.drop (s.groups.length - n) }
  /-- The uncommitted copy `c` lands. -/
  | landPending (u v : List AsyncCopy) (c : AsyncCopy) (gs : List (List AsyncCopy))
      (l : List AsyncCopy) : Step ⟨u ++ c :: v, gs, l⟩ none ⟨u ++ v, gs, l ++ [c]⟩
  /-- The copy `c` of a pending group lands. -/
  | landGroup (u : List AsyncCopy) (gs hs : List (List AsyncCopy)) (p q : List AsyncCopy)
      (c : AsyncCopy) (l : List AsyncCopy) :
      Step ⟨u, gs ++ (p ++ c :: q) :: hs, l⟩ none ⟨u, gs ++ (p ++ q) :: hs, l ++ [c]⟩

/-- The runs of `ops` from `s`: `Run s ops t` when the thread reaches `t` from `s` by the
operations `ops`, in order, with any number of landings before, between and after them. -/
inductive Run (s : Async) : List AsyncOp → Async → Prop
  /-- No operation and no landing. -/
  | nil : Run s [] s
  /-- A copy lands after a run of `ops`. -/
  | land {ops : List AsyncOp} {t u : Async} : Run s ops t → Step t none u → Run s ops u
  /-- The operation `o` after a run of `ops`. -/
  | op {ops : List AsyncOp} {t : Async} {o : AsyncOp} {u : Async} :
      Run s ops t → Step t (some o) u → Run s (ops ++ [o]) u

/-- One operation under the lazy completion choice: a copy joins the uncommitted copies; a commit
closes them into the newest group; `wait n` lands the oldest groups, in order, until at most `n`
remain. -/
def lazy (s : Async) : AsyncOp → Async
  | .copy c => { s with pending := s.pending ++ [c] }
  | .commit => { s with pending := [], groups := s.groups ++ [s.pending] }
  | .wait n => { s with groups := s.groups.drop (s.groups.length - n),
                        landed := s.landed ++ (s.groups.take (s.groups.length - n)).flatten }

/-- The operations `ops` in order from `s` under the lazy completion choice. -/
def lazyRun (s : Async) (ops : List AsyncOp) : Async :=
  ops.foldl lazy s

/-- The shared memory after the landed copies of `s`, in order, from `sm`, reading the global
memory `gm`. -/
def smem (gm sm : Nat → UInt8) (s : Async) : Nat → UInt8 :=
  s.landed.foldl (AsyncCopy.land gm) sm

private theorem lazyRun_append (s : Async) (ops ops' : List AsyncOp) :
    s.lazyRun (ops ++ ops') = ops'.foldl lazy (s.lazyRun ops) :=
  List.foldl_append ..

private theorem landOne {s : Async} {ops : List AsyncOp} {u : List AsyncCopy}
    {gs hs : List (List AsyncCopy)} :
    ∀ {g l : List AsyncCopy}, Run s ops ⟨u, gs ++ g :: hs, l⟩ →
      Run s ops ⟨u, gs ++ [] :: hs, l ++ g⟩
  | [], l, h => by simpa using h
  | c :: g, l, h => by
    simpa using landOne (g := g) (l := l ++ [c]) (.land h (.landGroup u gs hs [] g c l))

private theorem landAll {s : Async} {ops : List AsyncOp} {u : List AsyncCopy}
    {bs : List (List AsyncCopy)} :
    ∀ {as es : List (List AsyncCopy)} {l : List AsyncCopy}, Run s ops ⟨u, es ++ as ++ bs, l⟩ →
      Run s ops ⟨u, es ++ List.replicate as.length [] ++ bs, l ++ as.flatten⟩
  | [], es, l, h => by simpa using h
  | g :: as, es, l, h => by
    have h1 := landOne (s := s) (ops := ops) (u := u) (gs := es) (hs := as ++ bs) (g := g) (l := l)
      (by simpa using h)
    have e1 : es ++ [] :: (as ++ bs) = es ++ [[]] ++ as ++ bs := by simp
    have e2 : es ++ [[]] ++ List.replicate as.length [] ++ bs =
        es ++ List.replicate (g :: as).length [] ++ bs := by simp [List.replicate_succ]
    have e3 : l ++ g ++ as.flatten = l ++ (g :: as).flatten := by simp
    have h2 := landAll (as := as) (es := es ++ [[]]) (l := l ++ g) (e1 ▸ h1)
    rw [e2, e3] at h2
    exact h2

/-- **The lazy completion choice is a run**, from every state and for every sequence of
operations `ops`: a wait's copies land one by one, oldest group first, just before it. -/
theorem Run.lazy (s : Async) (ops : List AsyncOp) : Run s ops (s.lazyRun ops) := by
  induction ops using List.reverseRecOn with
  | nil => exact .nil
  | append_singleton ops o ih =>
    rw [lazyRun_append, List.foldl_cons, List.foldl_nil]
    generalize s.lazyRun ops = L at ih
    cases o with
    | copy c => exact .op ih (.copy L c)
    | commit => exact .op ih (.commit L)
    | wait n =>
      obtain ⟨P, G, D⟩ := L
      have h1 := landAll (s := s) (ops := ops) (u := P) (es := []) (as := G.take (G.length - n))
        (bs := G.drop (G.length - n)) (l := D) (by rwa [List.nil_append, List.take_append_drop])
      have hl : ([] ++ List.replicate (G.take (G.length - n)).length [] ++
          G.drop (G.length - n)).length - n = G.length - n := by
        simp only [List.nil_append, List.length_append, List.length_replicate, List.length_take,
          List.length_drop]
        omega
      have hk : ([] ++ List.replicate (G.take (G.length - n)).length
          ([] : List AsyncCopy)).length = G.length - n := by
        simp only [List.nil_append, List.length_replicate, List.length_take]
        omega
      have h2 := Run.op h1 (.wait _ n fun g hg => by
        dsimp only at hg
        rw [hl, List.take_left' hk, List.nil_append] at hg
        exact (List.mem_replicate.1 hg).2)
      simp only [hl, List.drop_left' hk] at h2
      exact h2

private theorem forall₂_mid {a b : List AsyncCopy} (hb : b <+ a) {hs : List (List AsyncCopy)} :
    ∀ {gs M : List (List AsyncCopy)}, List.Forall₂ (· <+ ·) (gs ++ a :: hs) M →
      List.Forall₂ (· <+ ·) (gs ++ b :: hs) M
  | [], _, h => by
    rw [List.nil_append] at h
    cases h with
    | cons h r => exact .cons (hb.trans h) r
  | _ :: _, _, h => by
    rw [List.cons_append] at h
    cases h with
    | cons h r => exact .cons h (forall₂_mid hb r)

private theorem flatten_sublist {A B : List (List AsyncCopy)} (h : List.Forall₂ (· <+ ·) A B) :
    A.flatten <+ B.flatten := by
  induction h with
  | nil => exact .slnil
  | cons h _ ih => exact h.append ih

private theorem flatten_wait {G : List (List AsyncCopy)} {k : Nat} (h : ∀ g ∈ G.take k, g = []) :
    G.flatten = (G.drop k).flatten := by
  conv_lhs => rw [← List.take_append_drop k G]
  rw [List.flatten_append, List.flatten_eq_nil_iff.2 h, List.nil_append]

/-- **Every run is the lazy run with some copies landed early**, from every state `s` and for
every sequence of operations `ops`: in every run of `ops` from `s` to `t`, the uncommitted copies
of `t` are a sublist of the lazy run's, each pending group of `t` is a sublist of the lazy run's
group at its place, and the landed copies followed by those not landed are a permutation of the
lazy run's. -/
theorem Run.within {s : Async} {ops : List AsyncOp} {t : Async} (h : Run s ops t) :
    t.pending <+ (s.lazyRun ops).pending ∧
      List.Forall₂ (· <+ ·) t.groups (s.lazyRun ops).groups ∧
      t.landed ++ t.unlanded ~ (s.lazyRun ops).landed ++ (s.lazyRun ops).unlanded := by
  induction h with
  | nil => exact ⟨.refl _, List.forall₂_same.2 fun _ _ => .refl _, .refl _⟩
  | land _ hs ih =>
    obtain ⟨h1, h2, h3⟩ := ih
    cases hs with
    | landPending u v c gs l =>
      refine ⟨((List.sublist_cons_self c v).append_left u).trans h1, h2,
        List.Perm.trans (List.perm_iff_count.2 fun a => ?_) h3⟩
      simp only [unlanded, List.count_append, List.count_cons, List.count_nil]
      omega
    | landGroup u gs hs p q c l =>
      refine ⟨h1, forall₂_mid ((List.sublist_cons_self c q).append_left p) h2,
        List.Perm.trans (List.perm_iff_count.2 fun a => ?_) h3⟩
      simp only [unlanded, List.flatten_append, List.flatten_cons, List.count_append,
        List.count_cons, List.count_nil]
      omega
  | @op ops t o u _ hs ih =>
    rw [lazyRun_append, List.foldl_cons, List.foldl_nil]
    obtain ⟨h1, h2, h3⟩ := ih
    cases hs with
    | copy _ c =>
      refine ⟨h1.append (.refl _), h2, List.perm_iff_count.2 fun a => ?_⟩
      have := List.perm_iff_count.1 h3 a
      simp only [Async.lazy, unlanded, List.count_append] at this ⊢
      omega
    | commit _ =>
      refine ⟨.slnil, List.rel_append h2 (.cons h1 .nil), ?_⟩
      simpa [Async.lazy, unlanded] using h3
    | wait _ n hw =>
      refine ⟨h1, ?_, List.perm_iff_count.2 fun a => ?_⟩
      · show List.Forall₂ _ (t.groups.drop (t.groups.length - n))
          ((s.lazyRun ops).groups.drop ((s.lazyRun ops).groups.length - n))
        rw [← h2.length_eq]
        exact List.forall₂_drop _ h2
      have := List.perm_iff_count.1 h3 a
      simp only [Async.lazy, unlanded, List.count_append] at this ⊢
      rw [← flatten_wait hw]
      rw [← List.take_append_drop ((s.lazyRun ops).groups.length - n) (s.lazyRun ops).groups,
        List.flatten_append, List.count_append] at this
      omega

private theorem unlanded_sub {s : Async} {ops : List AsyncOp} {t : Async} (h : Run s ops t) :
    t.unlanded <+ (s.lazyRun ops).unlanded :=
  (flatten_sublist h.within.2.1).append h.within.1

private theorem committed_append (ops : List AsyncOp) :
    committed ops ++ uncommitted ops = ops.filterMap AsyncOp.copy? := by
  rw [committed, uncommitted, ← List.filterMap_append, ← List.reverse_append,
    List.takeWhile_append_dropWhile, List.reverse_reverse]

/-- **The lazy run's landed copies and groups are the committed copies**, for every sequence of
operations `ops` from the empty state: under the lazy completion choice, the landed copies
followed by the pending groups' copies are `committed ops`, in order, and the copies not in a
group are `uncommitted ops`. -/
theorem lazyRun_init (ops : List AsyncOp) :
    (init.lazyRun ops).landed ++ (init.lazyRun ops).groups.flatten = committed ops ∧
      (init.lazyRun ops).pending = uncommitted ops := by
  induction ops using List.reverseRecOn with
  | nil => exact ⟨rfl, rfl⟩
  | append_singleton ops x ih =>
    rw [lazyRun_append, List.foldl_cons, List.foldl_nil]
    obtain ⟨h1, h2⟩ := ih
    cases x with
    | copy c =>
      have hc : committed (ops ++ [.copy c]) = committed ops := by
        simp [committed, AsyncOp.isCommit]
      have hu : uncommitted (ops ++ [.copy c]) = uncommitted ops ++ [c] := by
        simp [uncommitted, AsyncOp.isCommit, AsyncOp.copy?]
      rw [hc, hu]
      exact ⟨h1, congrArg (· ++ [c]) h2⟩
    | commit =>
      have hc : committed (ops ++ [.commit]) = ops.filterMap AsyncOp.copy? := by
        simp [committed, AsyncOp.isCommit, AsyncOp.copy?]
      have hu : uncommitted (ops ++ [.commit]) = [] := by
        simp [uncommitted, AsyncOp.isCommit]
      rw [hc, hu]
      refine ⟨?_, rfl⟩
      rw [← committed_append, ← h1, ← h2]
      simp [lazy]
    | wait n =>
      have hc : committed (ops ++ [.wait n]) = committed ops := by
        simp [committed, AsyncOp.isCommit]
      have hu : uncommitted (ops ++ [.wait n]) = uncommitted ops := by
        simp [uncommitted, AsyncOp.isCommit, AsyncOp.copy?]
      rw [hc, hu]
      refine ⟨?_, h2⟩
      rw [← h1]
      simp only [lazy, List.append_assoc, ← List.flatten_append, List.take_append_drop]

private theorem lazy_wait (ops : List AsyncOp) (n : Nat) :
    (init.lazyRun (ops ++ [.wait n])).groups.length ≤ n ∧
      (init.lazyRun (ops ++ [.wait n])).landed ++ (init.lazyRun (ops ++ [.wait n])).groups.flatten =
        committed ops := by
  rw [lazyRun_append, List.foldl_cons, List.foldl_nil]
  refine ⟨by simp only [lazy, List.length_drop]; omega, ?_⟩
  rw [← (lazyRun_init ops).1]
  simp only [lazy, List.append_assoc, ← List.flatten_append, List.take_append_drop]

/-- **After `wait_group n`, under every completion choice**, for every sequence of operations
`ops` from the empty state and every `n`: in every run of `ops` and `wait_group n`, at most `n`
groups are pending, and every copy that the lazy run has landed (by `lazyRun_init`, the
committed copies but those of the at most `n` pending groups) has landed, whatever else landed.
-/
theorem wait_run (ops : List AsyncOp) (n : Nat) {t : Async}
    (h : Run init (ops ++ [.wait n]) t) :
    t.groups.length ≤ n ∧ (init.lazyRun (ops ++ [.wait n])).landed <+~ t.landed := by
  obtain ⟨-, h2, h3⟩ := h.within
  refine ⟨by rw [h2.length_eq]; exact (lazy_wait ops n).1, List.subperm_iff_count.2 fun a => ?_⟩
  have e1 := List.perm_iff_count.1 h3 a
  have e2 := (unlanded_sub h).count_le a
  simp only [List.count_append] at e1
  omega

/-- **Visibility after `wait_group 0`, under every completion choice**, for every sequence of
operations `ops` from the empty state: in every run of `ops` and `wait_group 0`, no group is
pending, every copy issued before `ops`' last commit has landed, and the copies not landed are
among those issued after it, in order. -/
theorem visible (ops : List AsyncOp) {t : Async} (h : Run init (ops ++ [.wait 0]) t) :
    t.groups = [] ∧ committed ops <+~ t.landed ∧ t.pending <+ uncommitted ops := by
  obtain ⟨h0, hl⟩ := wait_run ops 0 h
  obtain ⟨g0, e⟩ := lazy_wait ops 0
  rw [List.eq_nil_of_length_eq_zero (Nat.le_zero.1 g0), List.flatten_nil, List.append_nil] at e
  refine ⟨List.eq_nil_of_length_eq_zero (Nat.le_zero.1 h0), by rw [← e]; exact hl, ?_⟩
  have hp := h.within.1
  rw [lazyRun_append, List.foldl_cons, List.foldl_nil] at hp
  rw [← (lazyRun_init ops).2]
  exact hp

private theorem land_writes (gm : Nat → UInt8) {c : AsyncCopy} {x : Nat} (h : c.Writes x)
    (sm sm' : Nat → UInt8) : c.land gm sm x = c.land gm sm' x := by
  simp only [AsyncCopy.land, eq_true h, ↓reduceIte]

private theorem land_not (gm sm : Nat → UInt8) {c : AsyncCopy} {x : Nat} (h : ¬ c.Writes x) :
    c.land gm sm x = sm x := by
  simp [AsyncCopy.land, h]

private theorem filterMap_op (ops : List AsyncOp) (o : AsyncOp) :
    (ops ++ [o]).filterMap AsyncOp.copy? = ops.filterMap AsyncOp.copy? ++ o.copy?.toList := by
  cases o <;> simp [AsyncOp.copy?]

private theorem last_writer (gm sm : Nat → UInt8) (x : Nat) (ops : List AsyncOp)
    (hx : ∀ p c q, ops = p ++ .copy c :: q → c.Writes x →
      ∀ d ∈ (init.lazyRun p).unlanded, ¬ d.Writes x) :
    ∀ e ∈ (init.lazyRun ops).unlanded, e.Writes x →
      (ops.filterMap AsyncOp.copy?).foldl (AsyncCopy.land gm) sm x = e.land gm sm x := by
  induction ops using List.reverseRecOn with
  | nil => intro e he; simp [init, unlanded, lazyRun] at he
  | append_singleton ops o ih =>
    have ih := ih fun p c q h => hx p c (q ++ [o]) (by rw [h]; simp)
    rw [lazyRun_append, List.foldl_cons, List.foldl_nil, filterMap_op]
    intro e he hw
    cases o with
    | copy c =>
      have he : e ∈ (init.lazyRun ops).unlanded ∨ e = c := by
        simpa [lazy, unlanded, or_assoc] using he
      simp only [AsyncOp.copy?, Option.toList_some, List.foldl_append, List.foldl_cons,
        List.foldl_nil]
      by_cases hc : c.Writes x
      · rcases he with he | rfl
        · exact absurd hw (hx ops c [] rfl hc e he)
        · exact land_writes gm hc _ _
      · rcases he with he | rfl
        · rw [land_not gm _ hc]
          exact ih e he hw
        · exact absurd hw hc
    | commit =>
      simp only [AsyncOp.copy?, Option.toList_none, List.append_nil]
      exact ih e (by simpa [lazy, unlanded] using he) hw
    | wait n =>
      simp only [AsyncOp.copy?, Option.toList_none, List.append_nil]
      refine ih e ?_ hw
      simp only [lazy, unlanded, List.mem_append, List.mem_flatten] at he ⊢
      rcases he with ⟨g, hg, he⟩ | he
      · exact .inl ⟨g, List.mem_of_mem_drop hg, he⟩
      · exact .inr he

private theorem settled (gm sm : Nat → UInt8) (x : Nat) {ops : List AsyncOp} {t : Async}
    (h : Run init ops t) :
    (∀ p c q, ops = p ++ .copy c :: q → c.Writes x →
      ∀ d ∈ (init.lazyRun p).unlanded, ¬ d.Writes x) →
    (∀ e ∈ t.unlanded, ¬ e.Writes x) →
    t.smem gm sm x = (ops.filterMap AsyncOp.copy?).foldl (AsyncCopy.land gm) sm x := by
  induction h with
  | nil => intro _ _; rfl
  | @land ops t u ht hs ih =>
    intro hx hu
    have hsub := unlanded_sub ht
    cases hs with
    | landPending a b c gs l =>
      simp only [smem, List.foldl_append, List.foldl_cons, List.foldl_nil]
      by_cases hc : c.Writes x
      · rw [land_writes gm hc _ sm]
        exact (last_writer gm sm x ops hx c (hsub.subset (by simp [unlanded])) hc).symm
      · rw [land_not gm _ hc]
        refine ih hx fun e he => ?_
        by_cases hec : e = c
        · subst hec
          exact hc
        · refine hu e ?_
          simp only [unlanded, List.mem_append, List.mem_cons] at he ⊢
          tauto
    | landGroup a gs hs p q c l =>
      simp only [smem, List.foldl_append, List.foldl_cons, List.foldl_nil]
      by_cases hc : c.Writes x
      · rw [land_writes gm hc _ sm]
        exact (last_writer gm sm x ops hx c (hsub.subset (by simp [unlanded])) hc).symm
      · rw [land_not gm _ hc]
        refine ih hx fun e he => ?_
        by_cases hec : e = c
        · subst hec
          exact hc
        · refine hu e ?_
          simp only [unlanded, List.flatten_append, List.flatten_cons, List.mem_append,
            List.mem_cons] at he ⊢
          tauto
  | @op ops t o u _ hs ih =>
    intro hx hu
    have ih := ih fun p c q h => hx p c (q ++ [o]) (by rw [h]; simp)
    rw [filterMap_op]
    cases hs with
    | copy _ c =>
      have hc : ¬ c.Writes x := hu c (by simp [unlanded])
      simp only [AsyncOp.copy?, Option.toList_some, List.foldl_append, List.foldl_cons,
        List.foldl_nil, land_not gm _ hc]
      exact ih fun e he => hu e (by simp only [unlanded, List.mem_append] at he ⊢; tauto)
    | commit _ =>
      simp only [AsyncOp.copy?, Option.toList_none, List.append_nil]
      exact ih fun e he => hu e (by simpa [unlanded] using he)
    | wait _ n hw =>
      simp only [AsyncOp.copy?, Option.toList_none, List.append_nil]
      exact ih fun e he => hu e (by rw [unlanded, flatten_wait hw] at he; exact he)

/-- **The protocol theorem: a byte no possibly pending copy writes is determined**, for every
sequence of operations `ops` from the empty state, global memory `gm`, initial shared memory
`sm` and shared byte `x`. Suppose every copy of `ops` that writes `x` is issued when no copy the
lazy run has not landed writes `x` (a byte is written again only after a wait for its previous
writer), and no copy the lazy run of `ops` has not landed writes `x`. Then in every run of `ops`
the shared memory holds at `x` the lazy run's byte, whatever landed early. -/
theorem determined (ops : List AsyncOp) (gm sm : Nat → UInt8) (x : Nat)
    (hx : ∀ p c q, ops = p ++ .copy c :: q → c.Writes x →
      ∀ d ∈ (init.lazyRun p).unlanded, ¬ d.Writes x)
    (hr : ∀ d ∈ (init.lazyRun ops).unlanded, ¬ d.Writes x) {t : Async} (h : Run init ops t) :
    t.smem gm sm x = (init.lazyRun ops).smem gm sm x := by
  rw [settled gm sm x h hx fun e he => hr e ((unlanded_sub h).subset he),
    settled gm sm x (Run.lazy init ops) hx hr]

private theorem foldl_land_out (gm : Nat → UInt8) (x : Nat) :
    ∀ (cs : List AsyncCopy) (sm : Nat → UInt8), (∀ c ∈ cs, ¬ c.Writes x) →
      cs.foldl (AsyncCopy.land gm) sm x = sm x
  | [], _, _ => rfl
  | c :: cs, sm, h => by
    rw [List.foldl_cons, foldl_land_out gm x cs _ fun d hd => h d (List.mem_cons_of_mem _ hd)]
    exact land_not gm sm (h c List.mem_cons_self)

private theorem foldl_land_mem (gm : Nat → UInt8) {c : AsyncCopy} {o : Nat} (ho : o < c.size) :
    ∀ (cs : List AsyncCopy) (sm : Nat → UInt8), cs.Pairwise AsyncCopy.Disjoint → c ∈ cs →
      cs.foldl (AsyncCopy.land gm) sm (c.dst + o) =
        if o < c.srcSize then gm (c.src + o) else 0
  | d :: cs, sm, hp, hc => by
    rw [List.pairwise_cons] at hp
    rw [List.foldl_cons]
    rcases List.mem_cons.1 hc with rfl | hc
    · rw [foldl_land_out gm _ cs _ fun e he ⟨h1, h2⟩ => by
        rcases hp.1 e he with h | h <;> omega]
      simp [AsyncCopy.land, AsyncCopy.Writes, ho]
    · exact foldl_land_mem gm ho cs _ hp.2 hc

private theorem mem_issued {p : List AsyncOp} {e : AsyncCopy}
    (he : e ∈ (init.lazyRun p).unlanded) : e ∈ p.filterMap AsyncOp.copy? := by
  rw [← committed_append, ← (lazyRun_init p).1, ← (lazyRun_init p).2]
  simp only [unlanded, List.mem_append] at he ⊢
  tauto

/-- **The copied bytes are visible after `wait_group 0`, under every completion choice**, for
every sequence of operations `ops` from the empty state, global memory `gm` and initial shared
memory `sm`: if the destinations of all the copies `ops` issues are pairwise disjoint, then for
every committed copy `c`, offset `o < c.size` and run of `ops` and `wait_group 0`, the shared
memory holds at `c.dst + o` the global byte `gm (c.src + o)` when `o < c.srcSize`, and `0`
otherwise. That nothing else writes the destinations or the sources while the copies are pending
is the caller's premise, not modelled. -/
theorem visible_bytes (ops : List AsyncOp) (gm sm : Nat → UInt8)
    (hd : (ops.filterMap AsyncOp.copy?).Pairwise AsyncCopy.Disjoint) {c : AsyncCopy}
    (hc : c ∈ committed ops) {o : Nat} (ho : o < c.size) {t : Async}
    (h : Run init (ops ++ [.wait 0]) t) :
    t.smem gm sm (c.dst + o) = if o < c.srcSize then gm (c.src + o) else 0 := by
  obtain ⟨g0, e⟩ := lazy_wait ops 0
  have hg := List.eq_nil_of_length_eq_zero (Nat.le_zero.1 g0)
  rw [hg, List.flatten_nil, List.append_nil] at e
  have hs := committed_append ops
  rw [determined (ops ++ [.wait 0]) gm sm _ ?_ ?_ h, smem, e]
  · exact foldl_land_mem gm ho _ sm (hd.sublist (by rw [← hs]; exact List.sublist_append_left _ _))
      hc
  · intro p d q hpq ⟨h1, h2⟩ e he ⟨h3, h4⟩
    have hf : ops.filterMap AsyncOp.copy? =
        p.filterMap AsyncOp.copy? ++ d :: q.filterMap AsyncOp.copy? := by
      have := congrArg (List.filterMap AsyncOp.copy?) hpq
      rw [filterMap_op] at this
      simpa [AsyncOp.copy?] using this
    rw [hf, List.pairwise_append] at hd
    rcases hd.2.2 e (mem_issued he) d List.mem_cons_self with h | h <;> omega
  · intro e he ⟨h3, h4⟩
    have hp : (init.lazyRun (ops ++ [.wait 0])).pending = uncommitted ops := by
      rw [lazyRun_append, List.foldl_cons, List.foldl_nil]
      exact (lazyRun_init ops).2
    rw [unlanded, hg, List.flatten_nil, List.nil_append, hp] at he
    rw [← hs, List.pairwise_append] at hd
    rcases hd.2.2 c hc e he with h | h <;> omega

end Async

end MojoProof.Sem
