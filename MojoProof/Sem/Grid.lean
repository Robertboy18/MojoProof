import MojoProof.Sem.Thread
import Mathlib.Logic.Relation

/-!
# The grid

A launch runs one thread per (block, thread index) pair; thread number `n` is thread `n % size` of
block `n / size`, where `size` is the block size, and the warp of a thread is its index divided
by 32 (indices in x, y, z order, x fastest). A thread's special registers come from the launch
(`Launch.env`).

* There is one memory. At the launch, each thread gets its own copy of each `byval` kernel
  argument, a block the thread owns, read-only if the parameter is `readonly` (`launchArgs`), and
  each block of threads gets its own shared memory, owned by it (`shared`): one block for each
  `internal` shared global (undefined bytes) and one block of `dynShared` bytes that every
  `external` shared global names (CUDA's dynamic shared memory). Thread `n` accesses memory as
  `⟨n, n / size⟩` (`Who`). The trace of the start memory is empty: it records the kernel's own
  accesses. The caller's memory is checked before any allocation (`Mem.checkClosed`): a launch
  on a memory with `next = 0`, a block 0, or a pointer (of the arguments, or in a byte of a block
  below `next`) to a number from `next` on is unsupported. The check reads no block from `next`
  on, so that the start's grid is closed takes the caller's hypothesis on those blocks' pointer
  bytes (`Grid.start_closed`). No block of the caller's memory is deleted or replaced: the
  launch's blocks take the numbers from `next` on, and one whose number has a block is unsupported
  (`Mem.allocNext`). So a pointer of the launch never comes to point into a block an `alloca`
  makes, and every block of the caller's memory is, unchanged, a block of the start memory.
* `Grid.Step` is one step of any schedule: a running thread takes a step (`Grid.advance`), or a
  collective call completes for all its participants (`Grid.fire`).
* `barrier.cta.sync.aligned.all` completes when every thread of the block waits at the same
  barrier instruction with the same barrier number. A thread of the block that waits at another
  barrier, or has returned, makes it undefined behavior: `.aligned` requires all threads of the
  block to execute the same barrier instruction (PTX ISA 9.5, section 9.7.15.1). PTX lets the
  other threads go on when some have exited; the semantics is stricter there. A barrier number
  outside 0-15 (PTX has 16 barriers per block, same section) is undefined behavior. Its
  completion is recorded in the memory's trace.
* `shfl.sync` is supported with the full member mask (all 32 bits) and the whole warp taking
  part (the lanes of a last, partial warp past the block are not threads): it completes when
  every lane of the warp waits at the same `shfl.sync` instruction with the same mode and mask,
  and each lane gets operand `a` of the source lane that PTX's pseudocode computes
  (`shflSource`; PTX ISA 9.5, section 9.7.10.6). Another mask, a lane that has returned and a
  lane waiting at another collective call are unsupported, with the reason. A member mask of the
  completing thread, or a lane or clamp operand of a waiting lane, that is not an integer (such
  as poison or `undef`) is undefined behavior; another lane's such mask counts as another mask.
  A shuffle orders no memory access: the trace records no completion of it, so accesses on both
  sides of it race (test "shuffle in a warp").
* `ldmatrix` and `mma` have no grid semantics yet (unsupported).

`Grid.run` is the evaluator: phases in which every thread runs until it waits or returns, then
every collective call that can complete does; no progress is a deadlock (undefined behavior).

Proved here: `Mem.compact` is the identity (`Mem.compact_eq`) and compiles to `Mem.tabulate`,
the same memory tabulated (`Mem.compact_csimp`); the check's loop `allBelow` is
`(List.range n).all` (`allBelow_eq_all`), which compiled code runs for it (`allBelow_csimp`);
a closed memory passes the start's
check (`Mem.checkClosed_of_closed`), for every memory and argument values; a start that
succeeds keeps every block of the caller's memory unchanged (`Grid.start_blocks`, through
`Mem.allocNext_blocks`, `shared_blocks`, `launchArgs_blocks` and the fold invariants
`foldlM_mem_inv`, `foldlM_inv`, cases of `foldlM_idx_inv`, an invariant indexed by the
position), and its contexts give thread `n` the program, the number
`n`, the launch's special registers and the oracle's row `n` (`Grid.start_ctx`), for every
program, kernel, launch, memory and choices; a fold in `Except` over elements of a predicate,
from a state of an invariant, succeeds with a state of the invariant when every step on such an
element does (`Sym.foldlM_res`), and an invariant indexed by the next number of a fold over
consecutive numbers that succeeds holds at its end (`Sym.foldlM_range'_inv`); on a memory with
no block from its `next` on (`Mem.FreeAbove`), a launch allocation succeeds and keeps it
(`Sym.allocNext_res`), and so does the shared memory of a block of threads whose globals `shared`
supports (`Sym.shared_res`), and so does the start's fold of the blocks' shared memories
(`Sym.sharedFold_res`); the four moved from MojoProof/Sym/Start.lean keep their names in
`MojoProof.Sym`, whose start results use them; every state `Grid.run` reaches is reachable by
`Grid.Step` (`Grid.run_reach`), for every program.
-/

namespace MojoProof.Sem

open LLVM

/-- A launch: the grid size in blocks and the block size in threads, by dimension, and the bytes
of dynamic shared memory. -/
structure Launch where
  /-- Builds a launch from its grid, block and dynamic shared memory sizes. -/
  mk ::
  /-- The grid's size in blocks, by dimension. -/
  grid : Dim → Nat
  /-- The block's size in threads, by dimension. -/
  block : Dim → Nat
  /-- The bytes of dynamic shared memory (0 by default). -/
  dynShared : Nat := 0

/-- The number of points of a box of sides `d`. -/
def volume (d : Dim → Nat) : Nat := d .x * d .y * d .z

/-- The coordinates of number `n` in a box of sides `d`, x fastest. -/
def coord (d : Dim → Nat) (n : Nat) : Dim → Nat
  | .x => n % d .x
  | .y => n / d .x % d .y
  | .z => n / (d .x * d .y) % d .z

/-- The special registers of thread number `n`. -/
def Launch.env (L : Launch) (n : Nat) : Env where
  sreg r d := match r with
    | .tid => coord L.block (n % volume L.block) d
    | .ntid => L.block d
    | .ctaid => coord L.grid (n / volume L.block) d
    | .nctaid => L.grid d
  laneid := n % volume L.block % 32

/-- The shared memory of block of threads `c`: a block for each `internal` shared global of `gs`,
with undefined bytes, read-only if the global is `constant` (LangRef, "Global Variables": its
contents never change), and one of `dyn` bytes for all `external` ones, owned by `c`; addresses
from `ch`. A global outside address space 3, a global with an initializer other than `undef`
and an `external` `constant` shared global (its block would be the writable dynamic shared
memory) are unsupported, and so is a block at a number that already has one
(`Mem.allocNext`). Returns the memory and the pointer each global names. -/
def shared (l : Layout) (gs : List Global) (dyn c : Nat) (ch : Nat → Nat) (m : Mem) :
    Except Fault (Mem × List (String × Ptr)) := do
  let al := gs.foldl (fun a g => if g.init.isNone then max a (g.align.getD (l.align g.ty)) else a) 1
  let (m, d) ← m.allocNext l 3 dyn al true false (.cta c) (ch 0) (ch 1)
  gs.zipIdx.foldlM (init := (m, [])) fun (m, acc) (g, i) => do
    if g.addrSpace ≠ 3 then throw (.unsupported "global outside shared memory")
    match g.init with
    | none =>
      if g.isConst then throw (.unsupported "external constant shared global")
      pure (m, (g.name, ⟨d, 0⟩) :: acc)
    | some .undef =>
      let (m, b) ← m.allocNext l 3 (l.size g.ty) (g.align.getD (l.align g.ty)) true g.isConst
        (.cta c) (ch (2 * i + 2)) (ch (2 * i + 3))
      pure (m, (g.name, ⟨b, 0⟩) :: acc)
    | some _ => throw (.unsupported "initialized global")

/-- `m` with its blocks, and their bytes below their sizes, tabulated: the same memory
(`Mem.compact_csimp`), whose lookups do not go through the history of stores. Compiled code runs
it for `Mem.compact`; it is private, as only `Mem.compact_csimp` names it. -/
private def Mem.tabulate (m : Mem) : Mem :=
  let tab := Array.ofFn (n := m.next) fun c => (m.blocks c).map fun b =>
    let bs := Array.ofFn (n := b.size) fun i => b.bytes i
    { b with bytes := fun i => if h : i < bs.size then bs[i] else b.bytes i }
  { m with blocks := fun c => if h : c < tab.size then tab[c] else m.blocks c }

/-- `m` itself. The start and the evaluator (`Grid.run`) apply it to the memory they hand on, and
compiled code runs `Mem.tabulate` for it, the same memory (`Mem.compact_csimp`), so that evaluated
lookups do not go through the history of stores. The kernel unfolds it in one step at every block
size; it does not reduce `Mem.tabulate` at a block of 16,384 bytes (`Array.ofFn` is a chain of
pushes). -/
def Mem.compact (m : Mem) : Mem := m

/-- **Compiled code may run `Mem.tabulate` for `Mem.compact`**: tabulating a memory gives the same
memory, for every memory. -/
@[csimp] theorem Mem.compact_csimp : @Mem.compact = @Mem.tabulate := by
  funext m
  show m = m.tabulate
  symm
  rcases m with ⟨blocks, next, trace⟩
  simp only [tabulate, Mem.mk.injEq, and_true]
  funext c
  split
  · simp only [Array.getElem_ofFn]
    cases blocks c with
    | none => rfl
    | some b =>
      simp only [Option.map_some, Option.some.injEq]
      rcases b with ⟨_, _, _, _, _, bytes, _, _⟩
      simp only [Block.mk.injEq, and_true, true_and]
      funext i
      split <;> simp
  · rfl

mutual
  /-- One more than the largest block number a pointer in the value names; 0 if it names none. -/
  def Val.bound : Val → Nat
    | .ptr p => p.block + 1
    | .vec xs | .agg xs => Val.bounds xs
    | _ => 0

  /-- One more than the largest block number a pointer in the values names. -/
  def Val.bounds : List Val → Nat
    | [] => 0
    | x :: xs => max x.bound (Val.bounds xs)
end

/-- Whether `f i` holds for every `i < n`, for every test `f` and number `n`: `f (n - 1)` first,
then the numbers below it. It is a `Nat.rec`, which the kernel reduces one number at a time,
without the tuples of earlier results a structural recursion builds; compiled code runs
`(List.range n).all f` for it, the same test (`allBelow_csimp`). -/
def allBelow (f : Nat → Bool) (n : Nat) : Bool :=
  Nat.rec (motive := fun _ => Bool) true (fun k ih => f k && ih) n

/-- `(List.range n).all f`: `allBelow` from 0 up (`allBelow_eq_all`). Compiled code runs it for
`allBelow`; it is private, as only `allBelow_csimp` names it. -/
private def allBelowRange (f : Nat → Bool) (n : Nat) : Bool := (List.range n).all f

/-- `allBelow f n` is `(List.range n).all f`, for every test `f` and number `n`. -/
theorem allBelow_eq_all (f : Nat → Bool) (n : Nat) : allBelow f n = (List.range n).all f := by
  induction n with
  | zero => rfl
  | succ n ih =>
    show (f n && allBelow f n) = _
    rw [ih, List.range_succ, List.all_append, List.all_cons, List.all_nil, Bool.and_true,
      Bool.and_comm]

/-- **Compiled code may run `allBelowRange` for `allBelow`**: the same test, for every test and
number (`allBelow_eq_all`). -/
@[csimp] theorem allBelow_csimp : @allBelow = @allBelowRange :=
  funext fun f => funext fun n => allBelow_eq_all f n

/-- Every pointer of `vs`, and every pointer byte below the size of a block of `m` numbered below
`next`, names a number below `next`. Both loops are `allBelow`, which the kernel reduces in time
linear in `next` and in each block's size, times the cost of reading a byte (`b.bytes i`). -/
def Mem.namesBelow (m : Mem) (vs : List Val) : Bool :=
  decide (Val.bounds vs ≤ m.next) && allBelow (fun c => match m.blocks c with
    | some b => allBelow (fun i => match b.bytes i with
      | .ptr p _ => decide (p.block < m.next)
      | _ => true) b.size
    | none => true) m.next

/-- The caller's memory `m` is closed for argument values `vs`: `next` is at least 1, no block
has the null pointer's number 0 or a number from `next` on, and every pointer of `vs`, or in a
byte below the size of a block, names a number below `next`. Every memory a caller can give has a
closed representation (a `next` above every number in use); the empty memory is closed for no
arguments (`Mem.closed_empty`). Kernel theorems take it as a hypothesis: the start checks
`pos`, `null` and `vals`, and `bytes` for the blocks below `next` (`Mem.checkClosed`), which is
all of `bytes` under `above`; on a closed memory its allocations find their
numbers free. -/
structure Mem.Closed (m : Mem) (vs : List Val) : Prop where
  /-- Builds `Mem.Closed` from its five fields. -/
  mk ::
  /-- `next` is at least 1. -/
  pos : 0 < m.next
  /-- No block has the null pointer's number 0. -/
  null : m.blocks 0 = none
  /-- No block has a number from `next` on. -/
  above : ∀ c, m.next ≤ c → m.blocks c = none
  /-- Every pointer of `vs` names a number below `next`. -/
  vals : Val.bounds vs ≤ m.next
  /-- Every pointer byte below the size of a block names a number below `next`. -/
  bytes : ∀ c b i p j, m.blocks c = some b → i < b.size → b.bytes i = .ptr p j → p.block < m.next

/-- The start's check of the caller's memory `m` for a launch on argument values `vs`:
unsupported unless `next` is at least 1, block 0 (the null
pointer's number) does not exist, and every pointer of `vs`, or in a byte below the size of a
block below `next`, names a number below `next` (`Mem.namesBelow`). It changes nothing: a
caller's block from `next` on, which no pointer of the launch reaches,
stays, and an allocation of the launch at its number is unsupported (`Mem.allocNext`), so the
start keeps every caller's block (`Grid.start_blocks`). It checks the fields of `Mem.Closed`
except `above`, which no function can check, and except the pointer bytes of blocks from `next`
on, which `above` says do not exist (a memory with `next = 2` and a block 5 holding a pointer to
block 100 passes); a closed memory passes (`Mem.checkClosed_of_closed`). The launch
allocates from `next` on, and the `alloca`s above that (`Mem.fresh`), at numbers no value of the
launch names: such a block is reached only through the pointer its `alloca` returns, and a
pointer to no block points to no block for the whole run, if every pointer byte of `m` names a
number below `next` or with a block (`Grid.start_reach_closed`). -/
def Mem.checkClosed (m : Mem) (vs : List Val) : Except Fault Unit :=
  if m.next = 0 ∨ (m.blocks 0).isSome then
    .error (.unsupported "caller memory with next 0 or a block 0")
  else if m.namesBelow vs then .ok ()
  else .error (.unsupported "caller memory naming a block from next on")

/-- `Mem.compact` is the identity, for every memory (by its definition). -/
theorem Mem.compact_eq (m : Mem) : m.compact = m := rfl

/-- The start's check passes on every memory that is closed for the argument values. -/
theorem Mem.checkClosed_of_closed {m : Mem} {vs : List Val} (h : m.Closed vs) :
    m.checkClosed vs = .ok () := by
  have hn : m.namesBelow vs = true := by
    rw [Mem.namesBelow, allBelow_eq_all]
    simp only [Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true, List.mem_range]
    refine ⟨h.vals, fun c _ => ?_⟩
    split
    · rename_i b hc
      rw [allBelow_eq_all]
      simp only [List.all_eq_true, List.mem_range]
      intro i hi
      split
      · rename_i p j hp
        exact decide_eq_true (h.bytes c b i p j hc hi hp)
      · rfl
    · rfl
  simp [Mem.checkClosed, h.null, Nat.pos_iff_ne_zero.mp h.pos, hn]

/-- The empty memory is closed for no arguments. -/
theorem Mem.closed_empty : ({} : Mem).Closed [] :=
  ⟨by decide, rfl, fun _ _ => rfl, by decide, fun _ _ _ _ _ h => by cases h⟩

/-- A thread of a grid: running, waiting at a call of a collective intrinsic with its arguments
and the callee's declaration (the thread as it was before the call), or returned. -/
inductive Status
  /-- The thread `t` runs. -/
  | run (t : Thread)
  /-- The thread waits at a call of collective intrinsic `i` with arguments `args` and the
  callee's declaration `fn`; `t` is the thread before the call. -/
  | wait (t : Thread) (i : Intrinsic) (args : List Val) (fn : Func)
  /-- The thread has returned. -/
  | done

/-- A grid: its threads by number, and the memory. -/
structure Grid where
  /-- Builds a grid from its threads and memory. -/
  mk ::
  /-- The threads, by number. -/
  threads : Array Status
  /-- The memory the threads share. -/
  mem : Mem

/-- The kernel `fn` of `prog` launched with `L` on argument values `args` and memory `m`: the
grid with every thread at the start, and the context of each thread number. Every address comes
from the skeleton choices `ch`: block of threads `b`'s shared memory reads
`ch (Nat.pair (b + 2) i)`, thread `n`'s `byval` copies `ch (Nat.pair 0 (Nat.pair n i))` and its
`alloca`s `ch (Nat.pair 1 (Nat.pair n j))` (`Ctx.addr`). Thread `n` gets the payload choices
`oracle n`. The kernel (`Func.check`) and then the caller's memory (`Mem.checkClosed`,
unsupported if a pointer names a block from `next` on) are checked before any allocation; the
memory is changed by nothing but the launch's allocations, each at a
number with no block (`Mem.allocNext`): the start keeps every block of `m`
(`Grid.start_blocks`), and no pointer of the launch names a number from `next` on but those of
the launch's blocks. -/
def Grid.start (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    (ch : Nat → Nat) (oracle : Nat → Nat → Nat) : Except Fault (Grid × (Nat → Ctx)) := do
  let l := prog.layout
  let size := volume L.block
  fn.check prog.module
  m.checkClosed args
  let (m, tabs) ← (List.range (volume L.grid)).foldlM (init := (m, [])) fun (m, acc) b => do
    let (m, tab) ← shared l prog.module.globals.toList L.dynShared b
      (fun i => ch (Nat.pair (b + 2) i)) m
    pure (m, acc ++ [tab])
  let (m, ts) ← (List.range (volume L.grid * size)).foldlM (init := (m, #[])) fun (m, ts) n => do
    let (m, args) ← launchArgs l m n fn args fun i => ch (Nat.pair 0 (Nat.pair n i))
    pure (m, ts.push (.run (← Thread.start fn args)))
  let ctx (n : Nat) : Ctx := { prog, env := L.env n, who := ⟨n, n / size⟩,
                               addr := fun j => ch (Nat.pair 1 (Nat.pair n j)), oracle := oracle n,
                               globals := fun s => (tabs.getD (n / size) []).lookup s }
  return ({ threads := ts, mem := { m.compact with trace := [] } }, ctx)

/-- **An invariant of a fold in `Except` that succeeds, indexed by the position.** For every step
function `f`, list `xs` and invariant `P` indexed by the number of elements folded: if every step
on entry `i` of `xs` that succeeds from a state of `P i` gives a state of `P (i + 1)`, then a fold
over `xs` that succeeds from a state of `P 0` gives a state of `P xs.length`. `foldlM_mem_inv`,
`Sym.foldlM_range'_inv` and `Sym.foldlM_zipIdx_inv` are its cases. -/
theorem foldlM_idx_inv {α β ε : Type} {f : β → α → Except ε β} :
    ∀ {P : Nat → β → Prop} (xs : List α),
      (∀ i a b b', xs[i]? = some a → f b a = .ok b' → P i b → P (i + 1) b') →
      ∀ {b r : β}, xs.foldlM f b = .ok r → P 0 b → P xs.length r
  | _, [], _, b, r, h, hb => by
    obtain rfl : b = r := Except.ok.inj h
    exact hb
  | P, a :: xs, hP, b, r, h, hb => by
    rw [List.foldlM_cons] at h
    cases h1 : f b a with
    | error e =>
      rw [h1] at h
      cases h
    | ok b1 =>
      rw [h1] at h
      exact foldlM_idx_inv (P := fun i => P (i + 1)) xs
        (fun i a' c c' ha => hP (i + 1) a' c c' ha) h (hP 0 a b b1 rfl h1 hb)

/-- An invariant of a fold in `Except` that succeeds: one that every step that succeeds on an
element of `Q` keeps, if every element of the list is of `Q` (`foldlM_idx_inv` at an invariant
that does not depend on the position). -/
theorem foldlM_mem_inv {α β ε : Type} {f : β → α → Except ε β} {P : β → Prop} {Q : α → Prop}
    (hP : ∀ b a b', Q a → f b a = .ok b' → P b → P b') (xs : List α) (b : β) {r : β}
    (hq : ∀ a ∈ xs, Q a) (hr : xs.foldlM f b = .ok r) (hb : P b) : P r :=
  foldlM_idx_inv (P := fun _ => P) xs
    (fun _ a _ _ ha => hP _ a _ (hq a (List.mem_of_getElem? ha))) hr hb

/-- An invariant of a fold in `Except` that succeeds: one that every step that succeeds keeps. -/
theorem foldlM_inv {α β ε : Type} {f : β → α → Except ε β} {P : β → Prop}
    (hP : ∀ b a b', f b a = .ok b' → P b → P b') (xs : List α) (b : β) {r : β}
    (hr : xs.foldlM f b = .ok r) (hb : P b) : P r :=
  foldlM_mem_inv (Q := fun _ => True) (fun b a b' _ => hP b a b') xs b (fun _ _ => trivial) hr hb

/-- A launch allocation that succeeds keeps every block. -/
theorem Mem.allocNext_blocks {l : Layout} {m m' : Mem} {space size align : Nat}
    {live readOnly : Bool} {owner : Owner} {addr gaddr : Nat} {init : List MemByte} {d : Nat}
    (h : m.allocNext l space size align live readOnly owner addr gaddr init = .ok (m', d))
    {b : Nat} {x : Block} (hb : m.blocks b = some x) : m'.blocks b = some x := by
  unfold Mem.allocNext at h
  split at h
  · cases h
  · rename_i hn
    cases h
    have hne : b ≠ m.next := by
      rintro rfl
      simp [hb] at hn
    simp [Mem.set, hne, hb]

/-- No block of `m` has a number from `next` on (the field `above` of `Mem.Closed`). -/
def Mem.FreeAbove (m : Mem) : Prop := ∀ c, m.next ≤ c → m.blocks c = none

/-- **A fold in `Except` that succeeds.** For every step function `f`, invariant `P` and
predicate `Q`: if every step from a state of `P`, on an element of `Q`, succeeds (`.ok`) with a
state of `P`, then the fold over a list of elements of `Q` from a state of `P` succeeds with a
state of `P`. Stated for every result `x` of the fold, so that a hypothesis `fold = .error e`
refutes itself. -/
theorem _root_.MojoProof.Sym.foldlM_res {α β ε : Type} {f : β → α → Except ε β} {P : β → Prop}
    {Q : α → Prop}
    (hf : ∀ b a x, Q a → P b → f b a = x → ∃ b', x = .ok b' ∧ P b') :
    ∀ (xs : List α) (b : β) (x : Except ε β), (∀ a ∈ xs, Q a) → P b → xs.foldlM f b = x →
      ∃ r, x = .ok r ∧ P r
  | [], b, _, _, hb, hx => ⟨b, hx.symm, hb⟩
  | a :: xs, b, x, hq, hb, hx => by
    rw [List.foldlM_cons] at hx
    obtain ⟨b', h1, hb'⟩ := hf b a _ (hq a List.mem_cons_self) hb rfl
    rw [h1] at hx
    exact Sym.foldlM_res hf xs b' x (fun y hy => hq y (List.mem_cons_of_mem a hy)) hb' hx

/-- **A launch allocation succeeds.** For every layout, memory `m` with `Mem.FreeAbove`, space,
size, alignment, liveness, owner, addresses and initial bytes: `Mem.allocNext` returns `.ok`, and
the memory it returns has `Mem.FreeAbove`. -/
theorem _root_.MojoProof.Sym.allocNext_res {l : Layout} {m : Mem} {space size align : Nat}
    {live readOnly : Bool} {owner : Owner} {addr gaddr : Nat} {init : List MemByte}
    {x : Except Fault (Mem × Nat)}
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
theorem _root_.MojoProof.Sym.shared_res {l : Layout} {gs : List Global} {dyn c : Nat}
    {ch : Nat → Nat} {m : Mem} {x : Except Fault (Mem × List (String × Ptr))}
    (hg : ∀ g ∈ gs, g.addrSpace = 3 ∧ (g.init = none ∧ g.isConst = false ∨ g.init = some .undef))
    (h : m.FreeAbove) (hx : shared l gs dyn c ch m = x) : ∃ r, x = .ok r ∧ r.1.FreeAbove := by
  unfold shared at hx
  simp only [bind, Except.bind] at hx
  split at hx
  · rename_i e he
    obtain ⟨r, hr, -⟩ := Sym.allocNext_res h he
    cases hr
  · rename_i v hv
    obtain ⟨r, hr, hA⟩ := Sym.allocNext_res h hv
    cases hr
    refine Sym.foldlM_res (P := fun r => r.1.FreeAbove) (Q := fun gi => gi.1 ∈ gs)
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
          obtain ⟨r, hr, -⟩ := Sym.allocNext_res hb he
          cases hr
        · rename_i w hw
          obtain ⟨r, hr, hA'⟩ := Sym.allocNext_res hb hw
          cases hr
          exact ⟨_, hy.symm, hA'⟩
      · rename_i v hv hne
        rcases hi with ⟨hn, -⟩ | hu
        · simp [hn] at hne
        · rw [hu] at hne
          exact absurd (Option.some.inj hne).symm hv

/-- **The shared memories of a list of blocks of threads are allocated.** For every layout,
globals `gs` as in `Sym.shared_res`, dynamic size, address choice `ch`, list of block numbers,
memory with `Mem.FreeAbove` and list of earlier tables: the fold of `Grid.start` that allocates
each listed block `b`'s shared memory (`shared`, with the address choices `ch (Nat.pair (b + 2) i)`)
and appends its table returns `.ok`, with a memory with `Mem.FreeAbove`. -/
theorem _root_.MojoProof.Sym.sharedFold_res {l : Layout} {gs : List Global} {dyn : Nat}
    {ch : Nat → Nat}
    (hg : ∀ g ∈ gs, g.addrSpace = 3 ∧ (g.init = none ∧ g.isConst = false ∨ g.init = some .undef))
    (bs : List Nat) {m : Mem} (acc : List (List (String × Ptr)))
    {x : Except Fault (Mem × List (List (String × Ptr)))} (h : m.FreeAbove)
    (hx : bs.foldlM (init := (m, acc)) (fun (m, acc) b => do
        let (m, tab) ← shared l gs dyn b (fun i => ch (Nat.pair (b + 2) i)) m
        pure (m, acc ++ [tab])) = x) :
    ∃ r, x = .ok r ∧ r.1.FreeAbove :=
  Sym.foldlM_res (P := fun r => r.1.FreeAbove) (Q := fun _ => True)
    (fun b k y _ hb hy => by
      simp only [bind, Except.bind, pure, Except.pure] at hy
      split at hy
      · rename_i e he
        obtain ⟨r, hr, -⟩ := Sym.shared_res hg hb he
        cases hr
      · rename_i v hv
        obtain ⟨r, hr, hA⟩ := Sym.shared_res hg hb hv
        cases hr
        exact ⟨_, hy.symm, hA⟩) bs _ x (fun _ _ => trivial) h hx

/-- **A fold over consecutive numbers in `Except` that succeeds**, with the number: for every step
function `f` and invariant `P` indexed by the next number, if every step on number `i` that
succeeds from a state of `P i` gives a state of `P (i + 1)`, then a fold over `s, …, s + n - 1`
that succeeds from a state of `P s` gives a state of `P (s + n)` (`foldlM_idx_inv` at
`List.range' s n`, whose entry `i` is `s + i`). -/
theorem _root_.MojoProof.Sym.foldlM_range'_inv {β ε : Type} {f : β → Nat → Except ε β}
    {P : Nat → β → Prop}
    (hP : ∀ i b b', f b i = .ok b' → P i b → P (i + 1) b') (n s : Nat) (b : β) {r : β}
    (hr : (List.range' s n).foldlM f b = .ok r) (hb : P s b) : P (s + n) r := by
  have := foldlM_idx_inv (P := fun i => P (s + i)) (List.range' s n) (fun i a c c' ha h1 hc => by
    have hi : i < n := by simpa using (List.getElem?_eq_some_iff.1 ha).1
    rw [List.getElem?_range' hi, Option.some.injEq, Nat.one_mul] at ha
    subst ha
    simpa only [Nat.add_assoc] using hP _ c c' h1 hc) hr hb
  rwa [List.length_range'] at this

/-- The shared memory of a block of threads keeps every block. -/
theorem shared_blocks {l : Layout} {gs : List Global} {dyn c : Nat} {ch : Nat → Nat} {m m' : Mem}
    {tab : List (String × Ptr)} (h : shared l gs dyn c ch m = .ok (m', tab)) {b : Nat} {x : Block}
    (hb : m.blocks b = some x) : m'.blocks b = some x := by
  unfold shared at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · rename_i v hv
    refine foldlM_inv (P := fun r => r.1.blocks b = some x) (fun r gi r' hs hr => ?_) _ _ h
      (Mem.allocNext_blocks hv hb)
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
          exact Mem.allocNext_blocks hv' hr
      · cases hs

/-- The arguments of a launch keep every block. -/
theorem launchArgs_blocks {l : Layout} {m m' : Mem} {n : Nat} {fn : Func} {args vs : List Val}
    {ch : Nat → Nat} (h : launchArgs l m n fn args ch = .ok (m', vs)) {b : Nat} {x : Block}
    (hb : m.blocks b = some x) : m'.blocks b = some x := by
  refine foldlM_inv (P := fun r => r.1.blocks b = some x) (fun r pv r' hs hr => ?_) _ _ h hb
  obtain ⟨m1, acc⟩ := r
  obtain ⟨⟨p, v⟩, i⟩ := pv
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hs
  split at hs
  · split at hs
    · split at hs
      · cases hs
      · rename_i v' hv'
        cases hs
        exact Mem.allocNext_blocks hv' hr
    · cases hs
  · split at hs
    · cases hs
    · cases hs
      exact hr

/-- **The start keeps every block of the caller's memory**: for every
program, kernel, launch, argument values, memory, address choice and oracle, if the launch
starts, every block of `m` is, unchanged, a block of the start grid's memory. -/
theorem Grid.start_blocks {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) {b : Nat} {x : Block}
    (hb : m.blocks b = some x) : g.mem.blocks b = some x := by
  unfold Grid.start at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  rename_i v1 h1
  have hm1 := foldlM_inv (P := fun r => r.1.blocks b = some x) (fun r k r' hs hr => by
    simp only [pure, Except.pure] at hs
    split at hs
    · cases hs
    · rename_i v hv
      cases hs
      exact shared_blocks hv hr) _ _ h1 hb
  split at h
  · cases h
  rename_i v2 h2
  have hm2 := foldlM_inv (P := fun r => r.1.blocks b = some x) (fun r k r' hs hr => by
    simp only [pure, Except.pure] at hs
    split at hs
    · cases hs
    · rename_i v hv
      split at hs
      · cases hs
      · cases hs
        exact launchArgs_blocks hv hr) _ _ h2 hm1
  cases h
  simpa [Mem.compact_eq] using hm2

/-- **The start's contexts give thread `n` the program, the number `n`** (in block of threads
`n / volume L.block`), **the launch's special registers for thread `n` (`L.env n`) and the
oracle's row `oracle n`**, for every program, kernel, launch, argument values, memory, address
choice and oracle. -/
theorem Grid.start_ctx {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (n : Nat) :
    (c n).prog = prog ∧ (c n).who = ⟨n, n / volume L.block⟩ ∧ (c n).env = L.env n ∧
      (c n).oracle = oracle n := by
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
  cases h
  exact ⟨rfl, rfl, rfl, rfl⟩

/-- Thread `n` takes one step; `none` if it is not running. -/
def Grid.advance (c : Nat → Ctx) (g : Grid) (n : Nat) : Except Fault (Option Grid) :=
  match g.threads[n]? with
  | some (.run t) => do
    match ← step (c n) t g.mem with
    | .next t' m => return some { threads := g.threads.set! n (.run t'), mem := m }
    | .wait i args r => return some { g with threads := g.threads.set! n (.wait t i args r) }
    | .done m => return some { threads := g.threads.set! n .done, mem := m }
  | _ => pure none

/-- A waiting thread past its call, with result `v` in the call's register. -/
def Thread.resume (t : Thread) (v : Option Val) : Thread :=
  match t.frames with
  | f :: rest =>
    let r := (f.fn.blocks.find? (·.label == f.label)).bind fun b => b.stmts[f.pc]?.bind (·.res)
    { frames := { f.set r v none with pc := f.pc + 1 } :: rest, k := t.k + 1 }
  | [] => t

/-- The instruction a thread is at: function, block, position. -/
def Thread.at (t : Thread) : Option (String × Nat × Nat) :=
  t.frames.head?.map fun f => (f.fn.name, f.label, f.pc)

/-- The number of an integer scalar. -/
def Val.word? : Val → Option Nat
  | .bits _ b => some b.toNat
  | _ => none

/-- The source lane of lane `lane` in a `shfl.sync` of mode `mode` with operands `b` and `c`
(PTX ISA 9.5, section 9.7.10.6, "Semantics"); the lane itself when the computed lane is out of
range. -/
def shflSource (mode : Shfl) (lane b c : Nat) : Nat :=
  let bval := b % 32
  let cval := c % 32
  let seg := c / 256 % 32
  let maxLane := lane &&& seg ||| cval &&& (31 ^^^ seg)
  let minLane := lane &&& seg
  let (j, ok) : Int × Bool := match mode with
    | .up => ((lane : Int) - bval, decide ((lane : Int) - bval ≥ maxLane))
    | .down => (lane + bval, decide (lane + bval ≤ maxLane))
    | .bfly => (lane ^^^ bval, decide (lane ^^^ bval ≤ maxLane))
    | .idx =>
      let j := minLane ||| bval &&& (31 ^^^ seg)
      (j, decide (j ≤ maxLane))
  if ok then j.toNat else lane

/-- The threads `ns` of `ts` that wait, resumed with results `v` under their callees' return
attributes in memory `m` (`withAttrs`). -/
def resumeAll (l : Layout) (m : Mem) (ts : Array Status) (ns : List Nat) (v : Nat → Option Val) :
    Except Fault (Array Status) :=
  ns.foldlM (init := ts) fun (ts : Array Status) n => match ts[n]? with
    | some (Status.wait t _ _ fn) => do
      return ts.set! n (.run (t.resume (← (v n).mapM (withAttrs l m fn.ret fn.retAttrs))))
    | _ => pure ts

/-- The collective call thread `n` waits at, completed for all its participants (their results
under the callee's return attributes, in thread `n`'s context), or `none`; `none` if thread `n`
does not wait. Every participant is looked at, so a fault at one is the result even when another
still runs.
- At a barrier the participants are the threads of `n`'s block of threads. One that waits at a
  barrier with another number or at another instruction, or has returned, is undefined behavior
  (as are an undefined barrier number and one outside 0-15). If no participant faults and one
  runs or waits at another collective call, the result is `none`; if all wait at this barrier,
  it completes.
- At a shuffle the participants are the lanes of `n`'s warp inside its block of threads. One that
  waits at another collective, or at this one with another mode, mask or instruction, or has
  returned, is unsupported (as is a partial member mask of `n`; another lane's undefined mask
  is another mask). An undefined member mask of `n`, and an undefined lane or clamp operand of a
  lane that waits here, are undefined behavior. If no lane faults and one runs, the result is
  `none`; if all wait here, it completes.
- `ldmatrix` and `mma`, and a collective call with ill-typed arguments, are unsupported. -/
def Grid.fire (L : Launch) (c : Nat → Ctx) (g : Grid) (n : Nat) :
    Except Fault (Option Grid) := do
  let some (.wait t i args _) := g.threads[n]? | return none
  let l := (c n).prog.layout
  let size := volume L.block
  match i, args with
  | .barrier, [x] =>
    let some bar := x.word? | throw (.ub "barrier number not defined")
    unless bar < 16 do throw (.ub "barrier number outside 0-15")
    let group := (List.range size).map (n / size * size + ·)
    let states : List Bool ← group.mapM fun k => match g.threads[k]? with
      | some (Status.wait t' .barrier [x'] _) =>
        if x'.word? = some bar ∧ t'.at = t.at then pure true
        else throw (.ub "threads of a block at different barriers")
      | some .done => throw (.ub "aligned barrier with a returned thread")
      | _ => pure false
    if states.all (·) then
      return some { threads := ← resumeAll l g.mem g.threads group fun _ => none,
                    mem := g.mem.log (.barrier (n / size)) }
    else return none
  | .shfl mode, [msk, _, _, _] =>
    let some mask := msk.word? | throw (.ub "shfl member mask not defined")
    unless mask = 2 ^ 32 - 1 do throw (.unsupported "shfl with a partial member mask")
    let lane := n % size % 32
    let base := n - lane
    let lanes := (List.range 32).filter fun j => n % size - lane + j < size
    let parts : List (Option (Nat × Val × Nat × Nat)) ← lanes.mapM fun j =>
      match g.threads[base + j]? with
      | some (Status.wait t' (.shfl mode') [msk', a, b, c] _) =>
        if mode' = mode ∧ msk'.word? = some mask ∧ t'.at = t.at then
          match b.word?, c.word? with
          | some b, some c => pure (some (j, a, b, c))
          | _, _ => throw (.ub "shfl lane or clamp operand not defined")
        else throw (.unsupported "lanes of a warp at different collectives")
      | some (Status.wait ..) => throw (.unsupported "lanes of a warp at different collectives")
      | some .done => throw (.unsupported "shfl in a warp with a returned lane")
      | _ => pure none
    let some parts := parts.mapM id | return none
    let src (j : Nat) : Val := ((parts.find? (·.1 = j)).map (·.2.1)).getD .poison
    let res (k : Nat) : Option Val :=
      (parts.find? (base + ·.1 = k)).map fun (j, _, b, c) => src (shflSource mode j b c)
    return some { g with threads := ← resumeAll l g.mem g.threads (parts.map (base + ·.1)) res }
  | .ldmatrix _, _ | .mma _, _ => throw (.unsupported "ldmatrix and mma in a grid")
  | _, _ => throw (.unsupported "collective call with ill-typed arguments")

/-- One step of any schedule: a running thread takes a step, or a collective call completes. -/
def Grid.Step (L : Launch) (c : Nat → Ctx) (g g' : Grid) : Prop :=
  ∃ n, g.advance c n = .ok (some g') ∨ g.fire L c n = .ok (some g')

/-- Thread `n` runs until it waits or returns, for at most `fuel` steps. -/
def Grid.runThread (c : Nat → Ctx) (n : Nat) : Nat → Grid → Except Fault Grid
  | 0, _ => throw (.unsupported "out of fuel")
  | fuel + 1, g => do
    match ← g.advance c n with
    | some g' => g'.runThread c n fuel
    | none => pure g

/-- Threads `ns` run in turn until each waits or returns. -/
def Grid.runAll (c : Nat → Ctx) (fuel : Nat) : List Nat → Grid → Except Fault Grid
  | [], g => pure g
  | n :: ns, g => do Grid.runAll c fuel ns (← g.runThread c n fuel)

/-- The collective calls threads `ns` wait at complete in turn, where they can; with whether one
did. -/
def Grid.fireAll (L : Launch) (c : Nat → Ctx) : List Nat → Grid → Except Fault (Grid × Bool)
  | [], g => pure (g, false)
  | n :: ns, g => do
    match ← g.fire L c n with
    | some g' => return ((← Grid.fireAll L c ns g').1, true)
    | none => Grid.fireAll L c ns g

/-- The evaluator: at most `phases` phases with at most `fuel` steps per thread and phase. -/
def Grid.run (L : Launch) (c : Nat → Ctx) (fuel : Nat) : Nat → Grid → Except Fault Grid
  | 0, _ => throw (.unsupported "out of phases")
  | phases + 1, g =>
    if g.threads.all (· matches .done) then pure g
    else do
      let ns := List.range g.threads.size
      let r ← Grid.fireAll L c ns (← Grid.runAll c fuel ns g)
      if r.2 then Grid.run L c fuel phases { r.1 with mem := r.1.mem.compact }
      else if r.1.threads.all (· matches .done) then pure r.1
      else throw (.ub "deadlock: no thread runs and no collective call completes")

namespace Grid

variable {L : Launch} {c : Nat → Ctx}

/-- What `Grid.runThread` returns is reachable by `Grid.Step`, for every launch, contexts, thread,
fuel and grid. -/
theorem runThread_reach {n : Nat} :
    ∀ {fuel : Nat} {g g' : Grid}, g.runThread c n fuel = .ok g' →
      Relation.ReflTransGen (Grid.Step L c) g g'
  | 0, g, g', h => by simp [runThread] at h
  | fuel + 1, g, g', h => by
    simp only [runThread, bind, Except.bind] at h
    split at h
    · cases h
    · rename_i o ho
      cases o with
      | none => cases h; exact .refl
      | some g₁ => exact .head ⟨n, .inl ho⟩ (runThread_reach h)

/-- What `Grid.runAll` returns is reachable by `Grid.Step`, for every launch, contexts, fuel, list
of threads and grid. -/
theorem runAll_reach {fuel : Nat} :
    ∀ {ns : List Nat} {g g' : Grid}, Grid.runAll c fuel ns g = .ok g' →
      Relation.ReflTransGen (Grid.Step L c) g g'
  | [], g, g', h => by cases h; exact .refl
  | n :: ns, g, g', h => by
    simp only [runAll, bind, Except.bind] at h
    split at h
    · cases h
    · rename_i g₁ h₁
      exact (runThread_reach h₁).trans (runAll_reach h)

/-- The grid `Grid.fireAll` returns is reachable by `Grid.Step`, for every launch, contexts, list
of threads and grid. -/
theorem fireAll_reach :
    ∀ {ns : List Nat} {g g' : Grid} {b : Bool}, Grid.fireAll L c ns g = .ok (g', b) →
      Relation.ReflTransGen (Grid.Step L c) g g'
  | [], g, g', b, h => by cases h; exact .refl
  | n :: ns, g, g', b, h => by
    simp only [fireAll, bind, Except.bind] at h
    split at h
    · cases h
    · rename_i o ho
      cases o with
      | none => exact fireAll_reach h
      | some g₁ =>
        simp only [pure, Except.pure] at h
        split at h
        · cases h
        · rename_i p hp
          cases h
          exact .head ⟨n, .inr ho⟩ (fireAll_reach hp)

/-- Every state the evaluator reaches is reachable by steps of some schedule. -/
theorem run_reach {fuel : Nat} :
    ∀ {phases : Nat} {g g' : Grid}, g.run L c fuel phases = .ok g' →
      Relation.ReflTransGen (Grid.Step L c) g g'
  | 0, g, g', h => by simp [run] at h
  | phases + 1, g, g', h => by
    simp only [run] at h
    split at h
    · cases h; exact .refl
    · simp only [bind, Except.bind] at h
      split at h
      · cases h
      · rename_i g₁ h₁
        split at h
        · cases h
        · rename_i r hr
          have hr' := (runAll_reach (L := L) h₁).trans (fireAll_reach hr)
          split at h
          · have := run_reach h
            rw [Mem.compact_eq] at this
            exact hr'.trans this
          · split at h
            · cases h; exact hr'
            · cases h

end Grid

end MojoProof.Sem
