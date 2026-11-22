import MojoProof.Sem.Grid

/-!
# When a launch starts: `Grid.start` returns a grid

`Grid.start` (MojoProof/Sem/Grid.lean) faults or returns the start's grid and contexts. Every
result here is for every program, kernel, launch, argument values, memory, address choice and
oracle.

* `Mem.FreeAbove`: no block of the memory has a number from `next` on (`Mem.Closed.above`).
* `foldlM_res`: a fold in `Except` whose every step, from a state of an invariant `P`, on an
  element of `Q`, succeeds with a state of `P`, succeeds with a state of `P`.
* `allocNext_res`: on a memory with `FreeAbove`, an allocation of the launch (`Mem.allocNext`)
  succeeds, for every size, alignment, owner, address and initial bytes, and keeps `FreeAbove`.
* `shared_res`: on such a memory the shared memory of a block of threads (`shared`) is allocated
  when every global is in address space 3 and is either external and not `constant` or
  initialized with `undef`.
* `launchArgs_res`: on such a memory the arguments of a thread (`launchArgs`) are made when every
  `byval(T)` parameter's argument encodes as a `T` (`Layout.encode`) and every other parameter's
  attributes accept its argument on every memory (`withAttrs`).
* `Grid.start_ok`: the launch starts when the kernel passes its check (`Func.check`), the
  caller's memory is closed for the arguments (`Mem.Closed`), the globals and arguments are as
  above, and the kernel has a body. No premise is about the launch, the address choice or the
  oracle: `Grid.start` checks none of them, and it does not compare the number of arguments with
  the number of parameters (it pairs them by `List.zip`).
* `foldlM_range'_inv`: an invariant indexed by the next number of a fold over consecutive numbers
  that succeeds.
* `Grid.start_args`: the start's grid has `volume L.grid * volume L.block` threads, each at the
  start of the kernel with the arguments `launchArgs` makes for it, whose blocks the grid's memory
  keeps.
* `Param.byval?`, `byvalBlock`, `LaunchArg`: a parameter's `byval` type, the block `launchArgs`
  makes for such an argument, and what it makes for each parameter. `foldlM_zipIdx_inv`: an
  invariant indexed by the position of a fold over a list with its indices.
  `launchArgs_byval`: every value `launchArgs` makes is its `LaunchArg` in the memory it returns.
  `Thread.start_regs`: a started thread's frame holds each argument in the register its
  parameter names, for the first parameter naming it.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- No block of `m` has a number from `next` on (the field `above` of `Mem.Closed`). -/
def _root_.MojoProof.Sem.Mem.FreeAbove (m : Mem) : Prop := ∀ c, m.next ≤ c → m.blocks c = none

/-- **A fold in `Except` that succeeds.** For every step function `f`, invariant `P` and
predicate `Q`: if every step from a state of `P`, on an element of `Q`, succeeds (`.ok`) with a
state of `P`, then the fold over a list of elements of `Q` from a state of `P` succeeds with a
state of `P`. Stated for every result `x` of the fold, so that a hypothesis `fold = .error e`
refutes itself. -/
theorem foldlM_res {α β ε : Type} {f : β → α → Except ε β} {P : β → Prop} {Q : α → Prop}
    (hf : ∀ b a x, Q a → P b → f b a = x → ∃ b', x = .ok b' ∧ P b') :
    ∀ (xs : List α) (b : β) (x : Except ε β), (∀ a ∈ xs, Q a) → P b → xs.foldlM f b = x →
      ∃ r, x = .ok r ∧ P r
  | [], b, _, _, hb, hx => ⟨b, hx.symm, hb⟩
  | a :: xs, b, x, hq, hb, hx => by
    rw [List.foldlM_cons] at hx
    obtain ⟨b', h1, hb'⟩ := hf b a _ (hq a List.mem_cons_self) hb rfl
    rw [h1] at hx
    exact foldlM_res hf xs b' x (fun y hy => hq y (List.mem_cons_of_mem a hy)) hb' hx

/-- **A launch allocation succeeds.** For every layout, memory `m` with `Mem.FreeAbove`, space,
size, alignment, liveness, owner, addresses and initial bytes: `Mem.allocNext` returns `.ok`, and
the memory it returns has `Mem.FreeAbove`. -/
theorem allocNext_res {l : Layout} {m : Mem} {space size align : Nat} {live readOnly : Bool}
    {owner : Owner} {addr gaddr : Nat} {init : List MemByte} {x : Except Fault (Mem × Nat)}
    (h : m.FreeAbove)
    (hx : m.allocNext l space size align live readOnly owner addr gaddr init = x) :
    ∃ r, x = .ok r ∧ r.1.FreeAbove := by
  unfold Mem.allocNext at hx
  rw [h m.next (Nat.le_refl _)] at hx
  simp only [Option.isSome_none, Bool.false_eq_true, ↓reduceIte, pure, Except.pure] at hx
  refine ⟨_, hx.symm, fun c hc => ?_⟩
  simp only [Mem.alloc, Mem.set] at hc ⊢
  have hne : c ≠ m.next := by omega
  simp only [hne, ↓reduceIte]
  exact h c (by omega)

/-- **The shared memory of a block of threads is allocated.** For every layout, globals `gs`,
dynamic size, block of threads, address choice and memory with `Mem.FreeAbove`: if every global
is in address space 3 and either has no initializer and is not `constant` or is initialized with
`undef`, then `shared` returns `.ok`, with a memory with `Mem.FreeAbove`. -/
theorem shared_res {l : Layout} {gs : List Global} {dyn c : Nat} {ch : Nat → Nat} {m : Mem}
    {x : Except Fault (Mem × List (String × Ptr))}
    (hg : ∀ g ∈ gs, g.addrSpace = 3 ∧ (g.init = none ∧ g.isConst = false ∨ g.init = some .undef))
    (h : m.FreeAbove) (hx : shared l gs dyn c ch m = x) : ∃ r, x = .ok r ∧ r.1.FreeAbove := by
  unfold shared at hx
  simp only [bind, Except.bind] at hx
  split at hx
  · rename_i e he
    obtain ⟨r, hr, -⟩ := allocNext_res h he
    cases hr
  · rename_i v hv
    obtain ⟨r, hr, hA⟩ := allocNext_res h hv
    cases hr
    refine foldlM_res (P := fun r => r.1.FreeAbove) (Q := fun gi => gi.1 ∈ gs)
      (fun b gi y hq hb hy => ?_) _ _ x (fun a ha => List.fst_mem_of_mem_zipIdx ha) hA hx
    obtain ⟨m1, acc⟩ := b
    obtain ⟨g, i⟩ := gi
    obtain ⟨h3, hi⟩ := hg g hq
    simp only [pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hy
    split at hy
    · rename_i hne
      exact absurd h3 hne
    · split at hy
      · split at hy
        · rename_i hn hc
          rcases hi with ⟨-, hc'⟩ | hu
          · simp [hc'] at hc
          · simp [hn] at hu
        · exact ⟨_, hy.symm, hb⟩
      · split at hy
        · rename_i e he
          obtain ⟨r, hr, -⟩ := allocNext_res hb he
          cases hr
        · rename_i w hw
          obtain ⟨r, hr, hA'⟩ := allocNext_res hb hw
          cases hr
          exact ⟨_, hy.symm, hA'⟩
      · rename_i v hv hne
        rcases hi with ⟨hn, -⟩ | hu
        · simp [hn] at hne
        · rw [hu] at hne
          exact absurd (Option.some.inj hne).symm hv

/-- **The arguments of a thread are made.** For every layout, memory with `Mem.FreeAbove`, thread
number, kernel `fn`, argument values `args` and address choice: if the argument of every
parameter with an attribute `byval(T)` encodes as a `T` (`Layout.encode`), and the attributes of
every parameter with no `byval` accept its argument on every memory (`withAttrs`), then
`launchArgs` returns `.ok`, with a memory with `Mem.FreeAbove`. -/
theorem launchArgs_res {l : Layout} {m : Mem} {n : Nat} {fn : Func} {args : List Val}
    {ch : Nat → Nat} {x : Except Fault (Mem × List Val)}
    (hbv : ∀ p v, (p, v) ∈ fn.params.zip args → ∀ t, Attr.ty "byval" t ∈ p.attrs →
      (l.encode t v).isSome)
    (hpl : ∀ p v, (p, v) ∈ fn.params.zip args → (∀ t, Attr.ty "byval" t ∉ p.attrs) →
      ∀ m : Mem, ∃ v', withAttrs l m p.ty p.attrs v = .ok v')
    (h : m.FreeAbove) (hx : launchArgs l m n fn args ch = x) : ∃ r, x = .ok r ∧ r.1.FreeAbove := by
  refine foldlM_res (P := fun r => r.1.FreeAbove) (Q := fun pv => pv.1 ∈ fn.params.zip args)
    (fun b pvi y hq hb hy => ?_) _ _ x (fun a ha => List.fst_mem_of_mem_zipIdx ha) h hx
  obtain ⟨m1, acc⟩ := b
  obtain ⟨⟨p, v⟩, i⟩ := pvi
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hy
  split at hy
  · rename_i t ht
    obtain ⟨a, ha, hfa⟩ := List.exists_of_findSome?_eq_some ht
    have hbt : Attr.ty "byval" t ∈ p.attrs := by
      split at hfa
      · cases hfa
        exact ha
      · cases hfa
    have hs := hbv p v hq t hbt
    split at hy
    · split at hy
      · rename_i e he
        obtain ⟨r, hr, -⟩ := allocNext_res hb he
        cases hr
      · rename_i w hw
        obtain ⟨r, hr, hA⟩ := allocNext_res hb hw
        cases hr
        exact ⟨_, hy.symm, hA⟩
    · rename_i hn
      obtain ⟨bs, hbs⟩ := Option.isSome_iff_exists.1 hs
      exact absurd hbs (hn bs)
  · rename_i hn
    have hnb : ∀ t, Attr.ty "byval" t ∉ p.attrs := fun t ht => by
      have := List.findSome?_eq_none_iff.1 hn _ ht
      simp at this
    obtain ⟨v', hv'⟩ := hpl p v hq hnb m1
    split at hy
    · rename_i e he
      rw [hv'] at he
      cases he
    · exact ⟨_, hy.symm, hb⟩

/-- **The launch starts.** For every program `prog`, kernel `fn`, launch `L`, argument values
`args`, memory `m`, address choice `ch` and oracle: `Grid.start` returns a grid and contexts
(`.ok`) if
* `fn` passes its check against the module (`Func.check`);
* `m` is closed for `args` (`Mem.Closed`);
* every global of the module is in address space 3 and either has no initializer and is not
  `constant` or is initialized with `undef` (`shared`);
* the argument of every `byval(T)` parameter encodes as a `T`, and the attributes of every other
  parameter accept its argument on every memory (`launchArgs`);
* `fn` has a body (`Thread.start`).

Arguments and parameters are paired by `List.zip`: no premise compares their numbers, since
`Grid.start` does not. -/
theorem Grid.start_ok {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    (ch : Nat → Nat) (oracle : Nat → Nat → Nat) (hf : fn.check prog.module = .ok ())
    (hC : m.Closed args)
    (hg : ∀ g ∈ prog.module.globals.toList,
      g.addrSpace = 3 ∧ (g.init = none ∧ g.isConst = false ∨ g.init = some .undef))
    (hbv : ∀ p v, (p, v) ∈ fn.params.zip args → ∀ t, Attr.ty "byval" t ∈ p.attrs →
      (prog.layout.encode t v).isSome)
    (hpl : ∀ p v, (p, v) ∈ fn.params.zip args → (∀ t, Attr.ty "byval" t ∉ p.attrs) →
      ∀ m : Mem, ∃ v', withAttrs prog.layout m p.ty p.attrs v = .ok v')
    (hb : 0 < fn.blocks.size) : ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c) := by
  cases hs : Grid.start prog fn L args m ch oracle with
  | ok r => exact ⟨r.1, r.2, rfl⟩
  | error e =>
    exfalso
    unfold Grid.start at hs
    simp only [bind, Except.bind, hf, Mem.checkClosed_of_closed hC] at hs
    have hA : m.FreeAbove := hC.above
    split at hs
    · rename_i e' he
      obtain ⟨r, hr, -⟩ := foldlM_res (P := fun r => r.1.FreeAbove) (Q := fun _ => True)
        (fun b k y _ hb' hy => by
          simp only [pure, Except.pure] at hy
          split at hy
          · rename_i e he
            obtain ⟨r, hr, -⟩ := shared_res hg hb' he
            cases hr
          · rename_i v hv
            obtain ⟨r, hr, hA'⟩ := shared_res hg hb' hv
            cases hr
            exact ⟨_, hy.symm, hA'⟩) _ _ _ (fun _ _ => trivial) hA he
      cases hr
    · rename_i v1 h1
      obtain ⟨r1, hr1, hA1⟩ := foldlM_res (P := fun r => r.1.FreeAbove) (Q := fun _ => True)
        (fun b k y _ hb' hy => by
          simp only [pure, Except.pure] at hy
          split at hy
          · rename_i e he
            obtain ⟨r, hr, -⟩ := shared_res hg hb' he
            cases hr
          · rename_i v hv
            obtain ⟨r, hr, hA'⟩ := shared_res hg hb' hv
            cases hr
            exact ⟨_, hy.symm, hA'⟩) _ _ _ (fun _ _ => trivial) hA h1
      cases hr1
      split at hs
      · rename_i e' he
        obtain ⟨r, hr, -⟩ := foldlM_res (P := fun r => r.1.FreeAbove) (Q := fun _ => True)
          (fun b k y _ hb' hy => by
            simp only [pure, Except.pure] at hy
            split at hy
            · rename_i e he
              obtain ⟨r, hr, -⟩ := launchArgs_res hbv hpl hb' he
              cases hr
            · rename_i v hv
              obtain ⟨r, hr, hA'⟩ := launchArgs_res hbv hpl hb' hv
              cases hr
              split at hy
              · rename_i e he
                unfold Thread.start at he
                rw [Array.getElem?_eq_getElem hb] at he
                cases he
              · exact ⟨_, hy.symm, hA'⟩) _ _ _ (fun _ _ => trivial) hA1 he
        cases hr
      · cases hs

/-- **A fold over consecutive numbers in `Except` that succeeds**, with the number: for every step
function `f` and invariant `P` indexed by the next number, if every step on number `i` that
succeeds from a state of `P i` gives a state of `P (i + 1)`, then a fold over `s, …, s + n - 1`
that succeeds from a state of `P s` gives a state of `P (s + n)`. -/
theorem foldlM_range'_inv {β ε : Type} {f : β → Nat → Except ε β} {P : Nat → β → Prop}
    (hP : ∀ i b b', f b i = .ok b' → P i b → P (i + 1) b') :
    ∀ (n s : Nat) (b : β) {r : β}, (List.range' s n).foldlM f b = .ok r → P s b → P (s + n) r
  | 0, s, b, r, hr, hb => by
    obtain rfl : b = r := Except.ok.inj hr
    exact hb
  | n + 1, s, b, r, hr, hb => by
    rw [List.range'_succ, List.foldlM_cons] at hr
    cases h1 : f b s with
    | error e => rw [h1] at hr; cases hr
    | ok b1 =>
      rw [h1] at hr
      have h' := foldlM_range'_inv hP n (s + 1) b1 hr (hP s b b1 h1 hb)
      rwa [Nat.add_assoc, Nat.add_comm 1 n] at h'

/-- **The start's threads, one by one.** For every program, kernel `fn`, launch, argument values,
memory, address choice `ch` and oracle whose start gives grid `g`: `g` has
`volume L.grid * volume L.block` threads, and every thread `k` of them runs at the start of `fn`
(`Thread.start`) with the arguments `launchArgs` makes for thread `k` (from some memory, with
thread `k`'s address choices), every block of the memory that `launchArgs` returns being, unchanged,
a block of `g`'s memory. -/
theorem Grid.start_args {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) :
    g.threads.size = volume L.grid * volume L.block ∧ ∀ k < g.threads.size,
      ∃ m₁ m₂ as t, launchArgs prog.layout m₁ k fn args (fun i => ch (Nat.pair 0 (Nat.pair k i))) =
        .ok (m₂, as) ∧ Thread.start fn as = .ok t ∧ g.threads[k]? = some (.run t) ∧
        ∀ b x, m₂.blocks b = some x → g.mem.blocks b = some x := by
  unfold Grid.start at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  rename_i v2 h2
  cases h
  rw [List.range_eq_range'] at h2
  have I := foldlM_range'_inv (P := fun i (r : Mem × Array Status) => r.2.size = i ∧ ∀ k < i,
      ∃ m₁ m₂ as t, launchArgs prog.layout m₁ k fn args (fun j => ch (Nat.pair 0 (Nat.pair k j))) =
        .ok (m₂, as) ∧ Thread.start fn as = .ok t ∧ r.2[k]? = some (.run t) ∧
        ∀ b x, m₂.blocks b = some x → r.1.blocks b = some x)
    (fun i r r' hs hr => by
      obtain ⟨m1, ts⟩ := r
      obtain ⟨hsz, hr⟩ := hr
      dsimp only at hsz hr
      simp only [pure, Except.pure] at hs
      split at hs
      · cases hs
      · rename_i v hv
        split at hs
        · cases hs
        · rename_i t ht
          cases hs
          refine ⟨by simp [hsz], fun k hk => ?_⟩
          by_cases hki : k < i
          · obtain ⟨m₁, m₂, as, t', h1, h2, h3, h4⟩ := hr k hki
            refine ⟨m₁, m₂, as, t', h1, h2, ?_, fun b x hb => launchArgs_blocks hv (h4 b x hb)⟩
            rw [Array.getElem?_push, ite_eq_right (by omega)]
            exact h3
          · obtain rfl : k = i := by omega
            refine ⟨m1, v.1, v.2, t, hv, ht, ?_, fun _ _ hb => hb⟩
            rw [Array.getElem?_push, ite_eq_left hsz.symm])
    _ 0 _ h2 ⟨rfl, fun k hk => absurd hk (Nat.not_lt_zero k)⟩
  rw [Nat.zero_add] at I
  refine ⟨I.1, fun k hk => ?_⟩
  have hk' : k < volume L.grid * volume L.block := by
    rw [← I.1]
    exact hk
  obtain ⟨m₁, m₂, as, t, h1, h2, h3, h4⟩ := I.2 k hk'
  exact ⟨m₁, m₂, as, t, h1, h2, h3, fun b x hb => by simpa [Mem.compact_eq] using h4 b x hb⟩

/-- The type `T` of the first `byval(T)` attribute of parameter `p`, the one `launchArgs` reads;
`none` if `p` has no `byval` attribute. -/
def _root_.MojoProof.LLVM.Param.byval? (p : Param) : Option Ty :=
  p.attrs.findSome? fun | .ty "byval" t => some t | _ => none

/-- The block `launchArgs` makes for thread `n`'s `byval(T)` argument at position `i` of the
kernel's parameters, holding bytes `bs`: in address space 0, of `l.size T` bytes, live, read-only
if `ro`, owned by thread `n`, at the addresses `ch (2 i)` and `ch (2 i + 1)` times `T`'s
alignment, modulo `2 ^ w` (`Mem.alloc`, `w` the width of an address-space-0 pointer). -/
def byvalBlock (l : Layout) (n : Nat) (ch : Nat → Nat) (i : Nat) (t : Ty) (ro : Bool)
    (bs : List MemByte) : Sem.Block :=
  { space := 0, size := l.size t, live := true, readOnly := ro, owner := .thread n,
    bytes := fun j => bs.getD j .undef, addr := ch (2 * i) * l.align t % 2 ^ (l.ptr 0).1,
    gaddr := ch (2 * i + 1) * l.align t % 2 ^ (l.ptr 0).1 }

/-- **Value `w` is what `launchArgs` makes in thread `n` for parameter `p` at position `i` from
argument `v`**, in memory `m` with address choice `ch`: if `p` has the attribute `byval(T)`
(`Param.byval?`), `w` points to offset 0 of a block of `m` that is `byvalBlock` of `v`'s
encoding as a `T`; otherwise `w` is `v` under `p`'s attributes (`withAttrs`) on some memory. -/
def LaunchArg (l : Layout) (m : Mem) (n : Nat) (ch : Nat → Nat) (i : Nat) (p : Param)
    (v w : Val) : Prop :=
  (∀ t, p.byval? = some t → ∃ b bs, w = .ptr ⟨b, 0⟩ ∧ l.encode t v = some bs ∧
      m.blocks b = some (byvalBlock l n ch i t (p.attrs.contains (.flag "readonly")) bs)) ∧
    (p.byval? = none → ∃ m', withAttrs l m' p.ty p.attrs v = .ok w)

/-- `LaunchArg` holds in every memory that keeps `m`'s blocks. -/
theorem LaunchArg.mono {l : Layout} {m m' : Mem} {n : Nat} {ch : Nat → Nat} {i : Nat}
    {p : Param} {v w : Val} (h : LaunchArg l m n ch i p v w)
    (hm : ∀ b x, m.blocks b = some x → m'.blocks b = some x) : LaunchArg l m' n ch i p v w :=
  ⟨fun t ht => by
    obtain ⟨b, bs, h1, h2, h3⟩ := h.1 t ht
    exact ⟨b, bs, h1, h2, hm _ _ h3⟩, h.2⟩

/-- **An invariant along a fold over a list with its indices.** For every step function `f` in
`Except` and invariant `P` indexed by the position: if every step on entry `i` of `xs` from a
state of `P i` that succeeds gives a state of `P (i + 1)`, then a fold over `xs.zipIdx` from a
state of `P 0` that succeeds gives a state of `P xs.length`. -/
theorem foldlM_zipIdx_inv {α β ε : Type} {f : β → α × Nat → Except ε β} {P : Nat → β → Prop}
    (xs : List α) (hP : ∀ i a b b', xs[i]? = some a → f b (a, i) = .ok b' → P i b → P (i + 1) b')
    {b r : β} (h : xs.zipIdx.foldlM f b = .ok r) (hb : P 0 b) : P xs.length r := by
  suffices key : ∀ (ys : List α) (s : Nat) (b : β),
      (∀ i a, ys[i]? = some a → xs[s + i]? = some a) →
      (ys.zipIdx s).foldlM f b = .ok r → P s b → P (s + ys.length) r by
    have := key xs 0 b (fun i a h => by rwa [Nat.zero_add]) h hb
    rwa [Nat.zero_add] at this
  intro ys
  induction ys with
  | nil =>
    intro s b _ h hb
    obtain rfl : b = r := Except.ok.inj h
    exact hb
  | cons y ys ih =>
    intro s b hy h hb
    rw [List.zipIdx_cons, List.foldlM_cons] at h
    cases h1 : f b (y, s) with
    | error e => rw [h1] at h; cases h
    | ok b1 =>
      rw [h1] at h
      have hs : xs[s]? = some y := by simpa using hy 0 y rfl
      have h' := ih (s + 1) b1 (fun i a ha => by
        have := hy (i + 1) a (by simpa using ha)
        rwa [show s + (i + 1) = s + 1 + i by omega] at this) h (hP s y b b1 hs h1 hb)
      rwa [List.length_cons, show s + (ys.length + 1) = s + 1 + ys.length by omega]

/-- **The arguments `launchArgs` makes.** For every layout, memory, thread number `n`, kernel
`fn`, argument values `args` and address choice `ch`: if `launchArgs` returns memory `m'` and
values `vs`, then there is one value per parameter with an argument, and the value at every
position `i` with parameter `p` and argument `v` is what `launchArgs` makes for them in `m'`
(`LaunchArg`: a pointer to the `byval` copy, a block of `m'`, or `v` under the attributes). -/
theorem launchArgs_byval {l : Layout} {m m' : Mem} {n : Nat} {fn : Func} {args vs : List Val}
    {ch : Nat → Nat} (h : launchArgs l m n fn args ch = .ok (m', vs)) :
    vs.length = (fn.params.zip args).length ∧ ∀ i p v w, fn.params[i]? = some p →
      args[i]? = some v → vs[i]? = some w → LaunchArg l m' n ch i p v w := by
  unfold launchArgs at h
  refine foldlM_zipIdx_inv (P := fun i (r : Mem × List Val) => r.2.length = i ∧
      ∀ j p v w, fn.params[j]? = some p → args[j]? = some v → r.2[j]? = some w →
        LaunchArg l r.1 n ch j p v w) (fn.params.zip args)
    (fun i pv r r' hpv hs hr => ?_) h ⟨rfl, fun _ _ _ _ _ _ hw => by simp at hw⟩
  obtain ⟨m1, acc⟩ := r
  obtain ⟨p, v⟩ := pv
  obtain ⟨hlen, hr⟩ := hr
  dsimp only at hlen hr
  obtain ⟨hp, hv⟩ := List.getElem?_zip_eq_some.1 hpv
  dsimp only at hp hv
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hs
  split at hs
  · rename_i t ht
    have ht' : p.byval? = some t := ht
    split at hs
    · rename_i bs hbs
      split at hs
      · cases hs
      · rename_i w hw
        cases hs
        unfold Mem.allocNext at hw
        split at hw
        · cases hw
        · rename_i hnx
          cases hw
          refine ⟨by simp [hlen], fun j q u x hq hu hx => ?_⟩
          by_cases hj : j < i
          · rw [List.getElem?_append_left (by omega)] at hx
            exact (hr j q u x hq hu hx).mono fun b y hb => by
              have hne : b ≠ m1.next := by
                rintro rfl
                simp [hb] at hnx
              simp [Mem.alloc, Mem.set, hne, hb]
          · have hji : j = i := by
              have hlt := (List.getElem?_eq_some_iff.1 hx).1
              simp only [List.length_append, List.length_cons, List.length_nil] at hlt
              omega
            subst hji
            rw [List.getElem?_append_right (by omega), hlen, Nat.sub_self] at hx
            simp only [List.getElem?_cons_zero, Option.some.injEq] at hx
            rw [hp] at hq
            rw [hv] at hu
            cases hq
            cases hu
            subst hx
            refine ⟨fun t' ht'' => ?_, fun hn => by rw [ht'] at hn; cases hn⟩
            rw [ht'] at ht''
            cases ht''
            exact ⟨m1.next, bs, rfl, hbs, by simp [Mem.alloc, Mem.set, byvalBlock]⟩
    · cases hs
  · rename_i hn
    have hn' : p.byval? = none := hn
    split at hs
    · cases hs
    · rename_i w hw
      cases hs
      refine ⟨by simp [hlen], fun j q u x hq hu hx => ?_⟩
      by_cases hj : j < i
      · rw [List.getElem?_append_left (by omega)] at hx
        exact hr j q u x hq hu hx
      · have hji : j = i := by
          have hlt := (List.getElem?_eq_some_iff.1 hx).1
          simp only [List.length_append, List.length_cons, List.length_nil] at hlt
          omega
        subst hji
        rw [List.getElem?_append_right (by omega), hlen, Nat.sub_self] at hx
        simp only [List.getElem?_cons_zero, Option.some.injEq] at hx
        rw [hp] at hq
        rw [hv] at hu
        cases hq
        cases hu
        subst hx
        exact ⟨fun t ht => (by rw [hn'] at ht; cases ht), fun _ => ⟨m1, hw⟩⟩

/-- **The registers of a thread at the start of a kernel.** For every kernel `fn`, values `ws`
and thread `t` that `Thread.start` gives: `t` has one frame `f`, and for every position `i` whose
parameter `p` names register `r`, no earlier parameter naming `r`, and value `w` at `i` of `ws`,
register `r` of `f` is `w`. -/
theorem Thread.start_regs {fn : Func} {ws : List Val} {t : Thread}
    (h : Thread.start fn ws = .ok t) : ∃ f, t.frames = [f] ∧ ∀ i p w r,
      fn.params[i]? = some p → p.name = some r →
      (fn.params.take i).all (·.name != some r) = true → ws[i]? = some w → f.regs r = some w := by
  unfold Thread.start at h
  cases hb : fn.blocks[0]? with
  | none => rw [hb] at h; cases h
  | some e =>
    rw [hb] at h
    cases h
    refine ⟨_, rfl, fun i p w r hp hr hu hw => ?_⟩
    show ((fn.params.zip ws).find? (·.1.name == some r)).map (·.2) = some w
    suffices key : ∀ (ps : List Param) (vs : List Val) (i : Nat), ps[i]? = some p →
        (ps.take i).all (·.name != some r) = true → vs[i]? = some w →
        ((ps.zip vs).find? (·.1.name == some r)).map (·.2) = some w from key _ _ i hp hu hw
    intro ps
    induction ps with
    | nil => intro vs i hp; simp at hp
    | cons q ps ih =>
      intro vs i hp hu hw
      cases vs with
      | nil => simp at hw
      | cons u vs =>
        cases i with
        | zero =>
          simp only [List.getElem?_cons_zero, Option.some.injEq] at hp hw
          subst hp hw
          simp [hr]
        | succ i =>
          simp only [List.getElem?_cons_succ] at hp hw
          simp only [List.take_succ_cons, List.all_cons, Bool.and_eq_true] at hu
          have hq : (q.name == some r) = false := by simpa using hu.1
          rw [List.zip_cons_cons, List.find?_cons, hq]
          exact ih vs i hp hu.2 hw

end MojoProof.Sym
