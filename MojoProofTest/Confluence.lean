import MojoProof.Sem.Confluence
import MojoProofTest.Writes
import MojoProofTest.Launch

/-!
# Instances and twins of `Mem.run_comm`, `Grid.advance_comm`, `Grid.pending_apart`,
`Grid.advance_fire_comm`, `Grid.fire_fire_comm`, L10's memory part and `Grid.advance_atomic_comm`

On `Closed.mem1` (block 1 of 8 undefined bytes of every thread, `next = 2`). The instance of
`Mem.run_comm`: the changes `ops₁` (bytes 0 to 3 of block 1 put, a write by thread 0 logged) and
`ops₂` (bytes 4 to 7 of block 1 put, a write by thread 1 logged, block 3 set) are apart (`apart`),
so both orders give the same blocks (`comm`) and the same trace (`same`); there byte 0 of block 1
is 7 and byte 4 is 8 (`bytes`). The twins: two puts at byte 0 of block 1 are not apart, and the two
orders give 8 and 7 there (`twin`); a write by thread 1 and a barrier of its block of threads are
not apart, and after a write by thread 0 the two orders give a trace that is not racy and one that
is, so not the same trace (`trace_twin`).

The instance of `Grid.advance_comm`: in the contexts `ctxOf n` (thread `n`), the grid `stores 4`
of thread 0 storing `7` at bytes 0 to 3 of block 1 and thread 1 storing `8` at bytes 4 to 7 is
closed, its threads own their allocas, and no write of either overlaps an access of the other, so
the two orders of their steps give the same grid (`diamond`). The twins: on `stores 0` both
threads store to bytes 0 to 3, the writes overlap, and the two orders give grids that differ at
byte 0 (`diamond_twin`); with one thread number in both contexts two threads at `alloca` take one
block, and after either step the other's faults (`who_twin`); a thread whose frame lists block 1,
of every thread, among its allocas makes the grid not `Grid.Owns`, and its return makes block 1
dead, after which the other thread's store to it faults, while in the other order both steps
succeed (`owns_twin`).

The instance of `Grid.start_reach_comm`: the launch on two threads of `%0 = alloca i32`,
`store i32 7, ptr %0`, `ret void`; after both `alloca`s (thread 0's takes block 2, thread 1's
block 4) both threads' steps, their stores, succeed, and the two orders give the same grid
(`start_diamond`). The twin of `n ≠ k`: in the launch of MojoProofTest/Launch.lean, thread 0's
step from `g4` succeeds and accesses nothing, but after it thread 0 is done and takes no step, so
with `n = k = 0` the second step does not succeed (`start_twin`).

The instance of `Grid.pending_apart`: the discipline `(tiles, tileOf)` cuts block 1 into two tiles
of 4 bytes, tile 0 for thread 0 and tile 1 for every other thread; on `stores 4` each thread's
store lies in its tile, so no write of either overlaps an access of the other (`stores_apart`).
The twins, on `stores 0`, where the conclusion fails (`diamond_twin`): with every thread in tile 0
both stores follow the discipline but the tiles are not different, and with `tileOf` thread 1's
store is neither in its tile nor to a block it owns (`apart_twins`). The instance of
`Grid.start_reach_comm_of_owned`: in `start_diamond`'s grid both stores are to blocks their
threads own, and the two orders give the same grid (`start_diamond`'s statement again, so an
`example` after `apart_twins`).

The instance of `Grid.advance_fire_comm`: the grid `fires` of thread 0 at barrier 0 and thread 1
storing to bytes 4 to 7 of block 1, after a write of those bytes by thread 0, in a launch of one
thread per block of threads (`Pending.launch 1`). In the contexts `ctxB n` (thread `n` of block of
threads `n`) the store is not of block of threads 0, and the two orders give the same grid
(`fire_diamond`). The twin: in the contexts `ctxOf n` (every thread of block of threads 0) the
barrier orders thread 1's store after thread 0's write in one order and not in the other, so one
trace is racy and the other not, and the grids are not the same (`fire_twin`). At a shuffle: the
grid `shfls` of thread 0 at a butterfly shuffle of `5` and thread 1 storing, in the same launch and
contexts `ctxB`, where thread 0's warp is thread 0 alone; the two orders give the same grid
(`shfl_diamond`), and the shuffle puts in thread 0's register 0 its own `5` under the callee's
`range(i32 0, 8)` (`shfl_value`).

The instance of `Grid.start_reach_fire_comm`: the kernel of MojoProofTest/Launch.lean (an
`alloca`, a store, barrier 0, `ret void`) launched on two blocks of one thread (`twoBlocks`); after
thread 0's three steps it waits at the barrier, and after thread 1's `alloca` its store succeeds,
the barrier completes, and the two orders give the same grid (`start_fire_diamond`). The twin:
`fire_twin`'s contexts `ctxOf` are no start's contexts for its launch, since the start's put
thread 1 in block of threads 1 (`start_fire_twin`, by `Grid.start_ctx`).

The instances of `Grid.fire_fire_comm`: the grid `bars` of threads 0 and 1 at barrier 0. In the
contexts `ctxB` with one thread per block of threads the two fires give different grids, and each
completes after the other, both orders giving the same grid (`bars_diamond`); in the contexts
`ctxOf` with both threads in one block of threads either fire gives one grid (`bars_same`); and two
lanes of one warp at a butterfly shuffle that swaps `5` and `6` give one grid from either lane
(`shfls_same`). The twin of the premise on layouts: in the contexts `ctxL` thread 0 has 64-bit and
thread 1 32-bit pointers, and at a shuffle of a `nonnull` pointer at address `2 ^ 32` thread 0's
fire keeps the pointer and thread 1's makes it poison, after which no fire completes, so neither
alternative holds (`layout_twin`). The instance of `Grid.start_fire_fire_comm`: `startB` after
thread 1's store and barrier, both threads at barrier 0 of their own blocks of threads
(`start_bars`).

L10's memory part, on block 1 of 8 undefined bytes. The instances of `Mem.load_store_codec` and
`Mem.load_store`: after thread 0 stores the `i32` 7 at offset 0, its load there gives 7
(`store_load`), and so does thread 1's load at alignment 2 (`store_load_other`). The twins: in a
block owned by thread 0, thread 0's store succeeds and thread 1's check fails before it and its load
faults after it (`load_other`); a poison `i0` is stored as no bytes, which load as `bits 0 0`
(`store_load_i0`). The instance of `Mem.load_scalar`: the load of `store_load` gives an `i32` scalar
(`load_scalar`); its twin: a load of a stored pointer gives the pointer, no scalar (`load_ptr`).
The instance of `Layout.scalar_round`: an undefined `i32` round-trips through its bytes
(`undef_round`); its twins: a poison `i0` does not (`poison_i0`), and a pointer has no bytes at
`i32` (`ptr_i32`). On `memZ` (block 1 of 8 bytes 0 of every thread, `next = 2`) thread `n`'s
bytes 0 to 3 of block 1 decode at `i32` to 0 (`zeros_decode`), and thread `n`'s `atomicrmw add` of
every `x` at offset 0 succeeds (`add_ok`); the instance of `Mem.update_comm`:
thread 0's add of 1 and thread 1's add of 2 succeed in both orders with the same blocks, `next` and
trace up to swaps (`update_comm`).

Two `atomicrmw`s in the diamond. For every context, operation `Stmt.checkAtomic` admits, operand `o`
and scope with a pointer to block 1 in register 0 in which `o` evaluates at `i32` to `x`, the
execution of `rmwOf op o` (`atomicrmw op ptr %0, i32 o seq_cst`) is `Mem.update` by `x` at
offset 0 of block 1 if `x` is a scalar of width 32, and otherwise a fault (`exec_rmw`), and so,
for every context and memory, is the step of the thread `rmwAt op o` at it (`step_rmw`; for grids
in `ctxOf`, `advance_rmw` and `advance_rmw_fault`). The grid `adds` of thread 0 at an `atomicrmw
add` of 1 and thread 1 at one of 2 on `memZ` is closed (`closed_of`, for every block 1 with no
pointer byte and every trace) and its threads own their allocas; both threads' steps succeed
(`adds_ok`).
The instance of `Grid.advance_atomic_comm`: the two orders of their steps give the same grid
(`atomic_comm`). The instance of `Grid.advance_comm`'s premise on conflicts: the two threads'
pending writes overlap, but no pending access of thread 0 conflicts with one of thread 1, and the
two orders give the same grid (`atomic_diamond`); the twin, two overlapping plain stores that
conflict, is `diamond_twin`.

Statements about these ops, memories, grids and launches, not about every op, grid or launch,
except `exec_rmw`, `step_rmw`, `advance_rmw` and `advance_rmw_fault`, which are about every
context (`ctxOf` for the last two), scope, memory, operation `Stmt.checkAtomic` admits and operand.
-/

namespace MojoProofTest.Confluence

open MojoProof.Sem MojoProof.LLVM MojoProofTest.Pending

/-- A write of 4 bytes at block 1 from offset `o` by thread `n`. -/
def ev (n : Nat) (o : Int) : Event := .access ⟨⟨n, 0⟩, ⟨1, o⟩, 4, true, none, false⟩

/-- Bytes 0 to 3 of block 1 put to `7`, and the write logged. -/
def ops₁ : List Mem.Op := [.put 1 0 (leBytes 4 7), .log (ev 0 0)]

/-- Bytes 4 to 7 of block 1 put to `8`, the write logged, and block 3 set. -/
def ops₂ : List Mem.Op := [.put 1 4 (leBytes 4 8), .log (ev 1 4), .set 3 (Pending.blk 4 true)]

/-- Every change of `ops₁` is apart from every change of `ops₂`. -/
theorem apart : ∀ o₁ ∈ ops₁, ∀ o₂ ∈ ops₂, o₁.Apart o₂ := by
  simp [ops₁, ops₂, Mem.Op.Apart, Mem.Op.block, leBytes, ev, Event.indep]
  intros
  omega

/-- On `Closed.mem1`, `ops₁` then `ops₂` gives the blocks `ops₂` then `ops₁` gives. -/
theorem comm :
    ((Closed.mem1.run ops₁).run ops₂).blocks = ((Closed.mem1.run ops₂).run ops₁).blocks :=
  (Closed.mem1.run_comm apart).1

/-- On `Closed.mem1`, the two orders of `ops₁` and `ops₂` give the same trace (`Trace.Same`). -/
theorem same :
    Trace.Same ((Closed.mem1.run ops₁).run ops₂).trace ((Closed.mem1.run ops₂).run ops₁).trace :=
  (Closed.mem1.run_comm apart).2.2

/-- After `ops₁` then `ops₂` on `Closed.mem1`, byte 0 of block 1 is `7` and byte 4 is `8`: both
puts took effect. -/
theorem bytes :
    (((Closed.mem1.run ops₁).run ops₂).blocks 1).map (fun x => (x.bytes 0, x.bytes 4)) =
      some (.byte 7, .byte 8) := by
  decide

/-- The twin: two puts at byte 0 of block 1 are not apart, and the two orders differ there. -/
theorem twin : ¬ (Mem.Op.put 1 0 [.byte 7]).Apart (.put 1 0 [.byte 8]) ∧
    ((Closed.mem1.apply (.put 1 0 [.byte 7])).apply (.put 1 0 [.byte 8])).blocks ≠
      ((Closed.mem1.apply (.put 1 0 [.byte 8])).apply (.put 1 0 [.byte 7])).blocks := by
  refine ⟨fun h => ?_, fun h => ?_⟩
  · rcases h with h | h
    · exact h rfl
    · exact absurd (h 0 le_rfl (by decide)) (by decide)
  have := congrArg (fun bs => (bs 1).map (·.bytes 0)) h
  revert this
  decide

/-- The twin at the trace: a write by thread 1 and a barrier of block of threads 0 are not apart,
and after a write by thread 0 at the same bytes the two orders give different traces. -/
theorem trace_twin : ¬ (Mem.Op.log (ev 1 0)).Apart (.log (.barrier 0)) ∧
    ¬ Trace.Same (((Closed.mem1.log (ev 0 0)).run [.log (ev 1 0)]).run [.log (.barrier 0)]).trace
      (((Closed.mem1.log (ev 0 0)).run [.log (.barrier 0)]).run [.log (ev 1 0)]).trace :=
  ⟨by simp [Mem.Op.Apart, ev, Event.indep], fun h => absurd h.racy (by decide)⟩

/-! ## The two-thread case of the diamond (`Grid.advance_comm`) -/

/-- Thread `n` of block of threads 0, in the context `ctx0`. -/
def ctxOf (n : Nat) : Ctx := { ctx0 with who := ⟨n, 0⟩ }

/-- `store i32 v, ptr %0`. -/
def storeOf (v : Int) : Stmt :=
  { res := none, inst := .store false ⟨.int 32, .int v⟩ ⟨.ptr 0, .loc 0⟩ none }

/-- A thread at `storeOf v` with a pointer to offset `o` of block 1 in register 0. -/
def storerAt (v o : Int) : Thread :=
  ⟨[{ fn := kernel #[storeOf v], label := 0, pc := 0,
      regs := fun n => if n = 0 then some (.ptr ⟨1, o⟩) else none, prods := fun _ => none,
      allocas := [], dest := none }], 0⟩

/-- Thread 0 at `storerAt 7 0` and thread 1 at `storerAt 8 o`, on `Closed.mem1`. -/
def stores (o : Int) : Grid :=
  { threads := #[.run (storerAt 7 0), .run (storerAt 8 o)], mem := Closed.mem1 }

/-- A grid on the memory of block 1 `b` with `next = 2` and any trace `tr` (`Closed.mem1` for
`b = blk 8 true` and `tr = []`) is closed if `b` holds no pointer byte, the threads name only
blocks 0 and 1, and the contexts have no globals. -/
theorem closed_of {c : Nat → Ctx} {ts : Array Status} {b : MojoProof.Sem.Block}
    {tr : List Event} (hc : ∀ n x, (c n).globals x = none) (hb : ∀ i p j, b.bytes i ≠ .ptr p j)
    (ht : ∀ (n : Nat) (s : Status), ts[n]? = some s → s.NamesIn (· < 2)) :
    ({ threads := ts, mem := { memOf [(1, b)] with next := 2, trace := tr } } : Grid).Closed c where
  null := Or.inl (by show 0 < 2; decide)
  threads n s hs := (ht n s hs).mono fun _ => Or.inl
  bytes c' b' i p j hc' _ hp := by
    simp only [memOf, List.lookup] at hc'
    split at hc'
    · cases hc'
      exact absurd hp (hb i p j)
    · cases hc'
  globals n x p h := by rw [hc] at h; cases h

/-- `storerAt v o` names only blocks 0 and 1. -/
theorem storerAt_namesIn (v o : Int) : (storerAt v o).NamesIn (· < 2) := by
  intro f hf r x hr
  simp only [storerAt, List.mem_singleton] at hf
  subst hf
  simp only at hr
  split at hr
  · cases hr
    simp [Val.NamesIn]
  · cases hr

/-- `stores o` is closed in the contexts `ctxOf`. -/
theorem stores_closed (o : Int) : (stores o).Closed ctxOf :=
  closed_of (fun _ _ => rfl) (fun _ _ _ => nofun) fun n s hs => by
    rcases n with _ | _ | n <;> simp at hs <;> subst hs <;> exact storerAt_namesIn _ _

/-- `stores o` has its frames' `alloca`s owned by their threads (it has none). -/
theorem stores_owns (o : Int) : (stores o).Owns ctxOf := fun n s hs => by
  rcases n with _ | _ | n <;> simp [stores] at hs <;> subst hs <;> simp [Status.AllocasIn, storerAt]

/-- The instance: on `stores 4` (thread 0 writes bytes 0 to 3 of block 1, thread 1 bytes 4 to 7),
the hypotheses of `Grid.advance_comm` hold, so the two threads' steps give the same grid in both
orders. -/
theorem diamond : ∃ gn gk g₁ g₂, (stores 4).advance ctxOf 0 = .ok (some gn) ∧
    (stores 4).advance ctxOf 1 = .ok (some gk) ∧ gn.advance ctxOf 1 = .ok (some g₁) ∧
    gk.advance ctxOf 0 = .ok (some g₂) ∧ g₁.Same g₂ := by
  obtain ⟨gn, hn⟩ : ∃ gn, (stores 4).advance ctxOf 0 = .ok (some gn) := ⟨_, rfl⟩
  obtain ⟨gk, hk⟩ : ∃ gk, (stores 4).advance ctxOf 1 = .ok (some gk) := ⟨_, rfl⟩
  obtain ⟨g₁, g₂, h₁, h₂, h⟩ := Grid.advance_comm (stores_closed 4) (stores_owns 4) (by decide)
    hn hk fun a a' ha ha' => by
      rw [show (stores 4).pending ctxOf 0 = [ev 0 0] from rfl, List.mem_singleton] at ha
      rw [show (stores 4).pending ctxOf 1 = [ev 1 4] from rfl, List.mem_singleton] at ha'
      simp only [ev, Event.access.injEq] at ha ha'
      subst ha ha'
      decide
  exact ⟨gn, gk, g₁, g₂, hn, hk, h₁, h₂, h⟩

/-- The twin of the premise on accesses: on `stores 0` both threads write bytes 0 to 3 of block 1,
two plain writes that conflict, and the two orders give grids that are not the same, with byte 0
of block 1 being `8` in one and `7` in the other. -/
theorem diamond_twin :
    (∃ a a', .access a ∈ (stores 0).pending ctxOf 0 ∧ .access a' ∈ (stores 0).pending ctxOf 1 ∧
      a.conflict a' = true) ∧
    ∃ gn gk g₁ g₂, (stores 0).advance ctxOf 0 = .ok (some gn) ∧
      (stores 0).advance ctxOf 1 = .ok (some gk) ∧ gn.advance ctxOf 1 = .ok (some g₁) ∧
      gk.advance ctxOf 0 = .ok (some g₂) ∧ ¬ g₁.Same g₂ := by
  refine ⟨⟨⟨⟨0, 0⟩, ⟨1, 0⟩, 4, true, none, false⟩, ⟨⟨1, 0⟩, ⟨1, 0⟩, 4, true, none, false⟩,
    ?_, ?_, by decide⟩, _, _, _, _, rfl, rfl, rfl, rfl, fun h => ?_⟩
  · rw [show (stores 0).pending ctxOf 0 = [ev 0 0] from rfl]
    exact List.mem_singleton_self _
  · rw [show (stores 0).pending ctxOf 1 = [ev 1 0] from rfl]
    exact List.mem_singleton_self _
  have := congrArg (fun bs => (bs 1).map (·.bytes 0)) h.2.1
  revert this
  decide

/-- Two threads at `alloca i32`, on `Closed.mem1`. -/
def allocs : Grid :=
  { threads := #[.run (thread #[alloc]), .run (thread #[alloc])], mem := Closed.mem1 }

/-- The twin of the premise on thread numbers: in the contexts `fun _ => ctx0` both threads of
`allocs` are thread 0, so both `alloca`s take block 2 (`Mem.fresh`), and after either thread's step
the other's faults. The grid is closed, its threads own their allocas and access nothing. -/
theorem who_twin :
    allocs.Closed (fun _ => ctx0) ∧ allocs.Owns (fun _ => ctx0) ∧
      allocs.pending (fun _ => ctx0) 0 = [] ∧ allocs.pending (fun _ => ctx0) 1 = [] ∧
      ∃ gn gk e e', allocs.advance (fun _ => ctx0) 0 = .ok (some gn) ∧
        allocs.advance (fun _ => ctx0) 1 = .ok (some gk) ∧
        gn.advance (fun _ => ctx0) 1 = .error e ∧ gk.advance (fun _ => ctx0) 0 = .error e' := by
  refine ⟨closed_of (fun _ _ => rfl) (fun _ _ _ => nofun) fun n s hs => ?_, fun n s hs => ?_,
    rfl, rfl, _, _, _, _, rfl, rfl, rfl, rfl⟩ <;>
  · rcases n with _ | _ | n <;> simp [allocs] at hs <;> subst hs <;>
      simp [Status.NamesIn, Thread.NamesIn, Frame.NamesIn, Status.AllocasIn, thread]

/-- Thread 0 at the `ret void` of `Writes.returner`, whose frame lists block 1 among its allocas,
and thread 1 at `storerAt 8 4`, on `Closed.mem1`. -/
def retStore : Grid :=
  { threads := #[.run Writes.returner, .run (storerAt 8 4)], mem := Closed.mem1 }

/-- The twin of the premise on allocas: `retStore` is closed and thread 0 accesses nothing, but
block 1 is of every thread, not thread 0's, so it is not `Grid.Owns`. Thread 0's return makes
block 1 dead, after which thread 1's store faults; in the other order both steps succeed. -/
theorem owns_twin :
    retStore.Closed ctxOf ∧ ¬ retStore.Owns ctxOf ∧ retStore.pending ctxOf 0 = [] ∧
      ∃ gn gk g₂ e, retStore.advance ctxOf 0 = .ok (some gn) ∧
        retStore.advance ctxOf 1 = .ok (some gk) ∧ gn.advance ctxOf 1 = .error e ∧
        gk.advance ctxOf 0 = .ok (some g₂) := by
  refine ⟨closed_of (fun _ _ => rfl) (fun _ _ _ => nofun) fun n s hs => ?_, fun h => ?_, rfl,
    _, _, _, _, rfl, rfl, rfl, rfl⟩
  · rcases n with _ | _ | n <;> simp at hs <;> subst hs
    · intro f hf r v hr
      simp [Writes.returner] at hf
      subst hf
      simp at hr
    · exact storerAt_namesIn _ _
  · obtain ⟨x, hx, ho⟩ := h 0 _ rfl _ List.mem_cons_self 1 List.mem_cons_self
    rw [Writes.mem1_owner 1 x hx] at ho
    cases ho

/-! ## From the start (`Grid.start_reach_comm`) -/

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- `%0 = alloca i32`, `store i32 7, ptr %0`. -/
def allocStore : Array Stmt :=
  #[{ res := some 0, inst := .alloca (.int 32) none none },
    { res := none, inst := .store false ⟨.int 32, .int 7⟩ ⟨.ptr 0, .loc 0⟩ none }]

/-- The kernel `@k`: `allocStore`, then `ret void`. -/
def kern : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "k", params := [],
    group := none, names := #["entry"], blocks := #[⟨0, allocStore, .ret none⟩] }

/-- The program of `kern` alone, with the default data layout. -/
def kprog : Program :=
  { module := { (default : Module) with funcs := #[kern] }, sha256 := "", layout := {},
    intrinsics := [], kernels := ["k"] }

/-- One block of two threads. -/
def two : Launch := ⟨fun _ => 1, fun | .x => 2 | _ => 1, 0⟩

/-- The launch of `kern` on `two` on the empty memory, with address choice and oracle 0. -/
def start2 : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start kprog kern two [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `start2`. -/
def run2 : Grid × (Nat → Ctx) :=
  match start2 with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨kprog, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩,
      fun _ => 0, fun _ => 0⟩)

/-- The start's contexts. -/
def c2 : Nat → Ctx := run2.2

/-- `g` after a step of thread `n`, or `g` if it takes none. -/
def adv2 (n : Nat) (g : Grid) : Grid :=
  match g.advance c2 n with
  | .ok (some g') => g'
  | _ => g

/-- After thread 0's `alloca`. -/
def after0 : Grid := adv2 0 run2.1

/-- After both `alloca`s, thread 0's first. -/
def both : Grid := adv2 1 after0

/-- The launch `start2` starts, with the grid `run2.1` and contexts `c2`. -/
theorem start2_eq : start2 = .ok (run2.1, c2) := rfl

/-- `both` is reachable from the start, by thread 0's step and then thread 1's. -/
theorem both_reach : Relation.ReflTransGen (Grid.Step two c2) run2.1 both :=
  (Relation.ReflTransGen.single (b := after0) ⟨0, .inl rfl⟩).tail ⟨1, .inl rfl⟩

/-- The instance: in `both`, reachable from the start, threads 0 and 1 are at their stores, to
blocks 2 and 4, so the hypotheses of `Grid.start_reach_comm` hold and the two orders of their
steps give the same grid. -/
theorem start_diamond : ∃ gn gk g₁ g₂, both.advance c2 0 = .ok (some gn) ∧
    both.advance c2 1 = .ok (some gk) ∧ gn.advance c2 1 = .ok (some g₁) ∧
    gk.advance c2 0 = .ok (some g₂) ∧ g₁.Same g₂ := by
  obtain ⟨gn, hn⟩ : ∃ gn, both.advance c2 0 = .ok (some gn) := ⟨_, rfl⟩
  obtain ⟨gk, hk⟩ : ∃ gk, both.advance c2 1 = .ok (some gk) := ⟨_, rfl⟩
  obtain ⟨g₁, g₂, h₁, h₂, h⟩ := Grid.start_reach_comm start2_eq (fun _ _ _ _ _ h => by cases h)
    both_reach (by decide) hn hk fun a a' ha ha' => by
      rw [show both.pending c2 0 = [.access ⟨⟨0, 0⟩, ⟨2, 0⟩, 4, true, none, false⟩] from rfl,
        List.mem_singleton] at ha
      rw [show both.pending c2 1 = [.access ⟨⟨1, 0⟩, ⟨4, 0⟩, 4, true, none, false⟩] from rfl,
        List.mem_singleton] at ha'
      simp only [Event.access.injEq] at ha ha'
      subst ha ha'
      decide
  exact ⟨gn, gk, g₁, g₂, hn, hk, h₁, h₂, h⟩

/-- The twin of `n ≠ k`: in the launch of MojoProofTest/Launch.lean, `g4` is reachable from the
start, thread 0 accesses nothing there and its step, the return, succeeds; after it thread 0 is
done and takes no step, so with `n = k = 0` the step of `k` after that of `n` does not succeed. -/
theorem start_twin : Relation.ReflTransGen (Grid.Step .one Launch.c) Launch.g0 Launch.g4 ∧
    Launch.g4.pending Launch.c 0 = [] ∧ Launch.g4.advance Launch.c 0 = .ok (some Launch.g5) ∧
    Launch.g5.advance Launch.c 0 = .ok none :=
  ⟨Launch.reach4, rfl, Launch.steps.2.2.2.2, rfl⟩

/-! ## The premise on accesses from ownership (`Grid.pending_apart`) -/

/-- The tiling of block 1 into two tiles of 4 bytes, and no tiling of the other blocks. -/
def tiles (b : Nat) : Option (Tiling (Fin 2)) := if b = 1 then some (.strided 0 2 4) else none

/-- Thread 0's tile is tile 0, every other thread's tile 1. -/
def tileOf (n : Nat) : Fin 2 := if n = 0 then 0 else 1

/-- A write of 4 bytes at offset `4 * i` of block 1 by a thread to which `own` gives tile `i`
follows the discipline `(tiles, own)`. -/
theorem owned_store {own : Nat → Fin 2} {n : Nat} {o : Int} (ho : o = 4 * (own n : Nat)) :
    Owned tiles own ⟨⟨n, 0⟩, ⟨1, o⟩, 4, true, none, false⟩ :=
  ⟨fun h => by simp [tiles] at h, fun t ht => by
    simp only [tiles, ↓reduceIte, Option.some.injEq] at ht
    subst ht ho
    simp only [Tiling.strided, Tiling.ofApart]
    omega⟩

/-- The instance of `Grid.pending_apart`: on `stores 4` thread 0's store lies in tile 0 of block
1 and thread 1's in tile 1, so neither's write overlaps an access of the other. -/
theorem stores_apart : ∀ a a', .access a ∈ (stores 4).pending ctxOf 0 →
    .access a' ∈ (stores 4).pending ctxOf 1 → a.overlaps a' = true →
      a.write = false ∧ a'.write = false := by
  obtain ⟨gn, hn⟩ : ∃ gn, (stores 4).advance ctxOf 0 = .ok (some gn) := ⟨_, rfl⟩
  obtain ⟨gk, hk⟩ : ∃ gk, (stores 4).advance ctxOf 1 = .ok (some gk) := ⟨_, rfl⟩
  refine Grid.pending_apart (T := tiles) (own := tileOf) hn hk (by decide) fun p hp a ha => .inl ?_
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
  rcases hp with rfl | rfl
  · rw [show (stores 4).pending ctxOf 0 = [ev 0 0] from rfl, List.mem_singleton] at ha
    cases ha
    exact owned_store (by decide)
  · rw [show (stores 4).pending ctxOf 1 = [ev 1 4] from rfl, List.mem_singleton] at ha
    cases ha
    exact owned_store (by decide)

/-- The twins of the premises of `Grid.pending_apart`, on `stores 0`, where both threads write
bytes 0 to 3 of block 1, so that the conclusion fails (`diamond_twin`): with every thread in tile
0 both stores follow the discipline, but the threads' tiles are one; with `tileOf` the tiles
differ, but thread 1's store is neither in its tile nor in a block thread 1 owns. -/
theorem apart_twins :
    (∀ p ∈ [0, 1], ∀ a, .access a ∈ (stores 0).pending ctxOf p →
      Owned tiles (fun _ => 0) a ∨ (stores 0).mem.Owned (ctxOf p).who.thread a.ptr.block) ∧
    ¬ ∀ p ∈ [0, 1], ∀ a, .access a ∈ (stores 0).pending ctxOf p →
      Owned tiles tileOf a ∨ (stores 0).mem.Owned (ctxOf p).who.thread a.ptr.block := by
  refine ⟨fun p hp a ha => .inl ?_, fun h => ?_⟩
  · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
    rcases hp with rfl | rfl
    · rw [show (stores 0).pending ctxOf 0 = [ev 0 0] from rfl, List.mem_singleton] at ha
      cases ha
      exact owned_store (by decide)
    · rw [show (stores 0).pending ctxOf 1 = [ev 1 0] from rfl, List.mem_singleton] at ha
      cases ha
      exact owned_store (by decide)
  rcases h 1 (by simp) _ (show ev 1 0 ∈ (stores 0).pending ctxOf 1 from List.mem_singleton_self _)
    with h | ⟨x, hx, ho⟩
  · exact absurd (h.tile _ rfl).1 (by decide)
  · obtain ⟨y, hy, hy'⟩ : ∃ y, (stores 0).mem.blocks 1 = some y ∧ y.owner = .all := ⟨_, rfl, rfl⟩
    rw [hy] at hx
    cases hx
    rw [hy'] at ho
    cases ho

/- The instance of `Grid.start_reach_comm_of_owned`: in `both`, reachable from the start, threads 0
and 1 store to their own `alloca`s, blocks 2 and 4, which they own, so with no tiled block the
two orders of their steps give the same grid. `start_diamond`'s statement, by the other theorem,
so an `example`. -/
example : ∃ gn gk g₁ g₂, both.advance c2 0 = .ok (some gn) ∧
    both.advance c2 1 = .ok (some gk) ∧ gn.advance c2 1 = .ok (some g₁) ∧
    gk.advance c2 0 = .ok (some g₂) ∧ g₁.Same g₂ := by
  obtain ⟨gn, hn⟩ : ∃ gn, both.advance c2 0 = .ok (some gn) := ⟨_, rfl⟩
  obtain ⟨gk, hk⟩ : ∃ gk, both.advance c2 1 = .ok (some gk) := ⟨_, rfl⟩
  have hH : ∀ p ∈ [0, 1], ∀ a, .access a ∈ both.pending c2 p → both.mem.Owned p a.ptr.block := by
    intro p hp a ha
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
    rcases hp with rfl | rfl
    · rw [show both.pending c2 0 = [.access ⟨⟨0, 0⟩, ⟨2, 0⟩, 4, true, none, false⟩] from rfl,
        List.mem_singleton] at ha
      cases ha
      exact ⟨_, rfl, rfl⟩
    · rw [show both.pending c2 1 = [.access ⟨⟨1, 0⟩, ⟨4, 0⟩, 4, true, none, false⟩] from rfl,
        List.mem_singleton] at ha
      cases ha
      exact ⟨_, rfl, rfl⟩
  obtain ⟨g₁, g₂, h₁, h₂, h⟩ := Grid.start_reach_comm_of_owned
    (T := fun _ => (none : Option (Tiling Nat))) (own := id) start2_eq
    (fun _ _ _ _ _ h => by cases h) both_reach (by decide) hn hk
    fun p hp a ha => .inr (hH p hp a ha)
  exact ⟨gn, gk, g₁, g₂, hn, hk, h₁, h₂, h⟩

/-! ## A thread and a barrier (`Grid.advance_fire_comm`) -/

/-- Thread 0 at barrier 0 (`Pending.atBarrier`) and thread 1 at `storerAt 8 4`, on `Closed.mem1`
with a write of bytes 4 to 7 of block 1 by thread 0 logged. -/
def fires : Grid :=
  { threads := #[atBarrier, .run (storerAt 8 4)], mem := Closed.mem1.log (ev 0 4) }

/-- Thread `n` of block of threads `n`, in the context `ctx0`. -/
def ctxB (n : Nat) : Ctx := { ctx0 with who := ⟨n, n⟩ }

/-- The instance: in the contexts `ctxB`, with one thread per block of threads, thread 1's store is
not of block of threads 0, whose barrier thread 0 waits at, so the two orders of the store and the
barrier give the same grid. -/
theorem fire_diamond : ∃ gk gf g₁ g₂, fires.advance ctxB 1 = .ok (some gk) ∧
    fires.fire (Pending.launch 1) ctxB 0 = .ok (some gf) ∧
    gk.fire (Pending.launch 1) ctxB 0 = .ok (some g₁) ∧ gf.advance ctxB 1 = .ok (some g₂) ∧
    g₁.Same g₂ := by
  obtain ⟨gk, hk⟩ : ∃ gk, fires.advance ctxB 1 = .ok (some gk) := ⟨_, rfl⟩
  obtain ⟨gf, hf⟩ : ∃ gf, fires.fire (Pending.launch 1) ctxB 0 = .ok (some gf) := ⟨_, rfl⟩
  obtain ⟨g₁, g₂, h₁, h₂, h⟩ := Grid.advance_fire_comm hk hf (by decide)
  exact ⟨gk, gf, g₁, g₂, hk, hf, h₁, h₂, h⟩

/-- The twin of the premise on blocks of threads: in the contexts `ctxOf`, thread 1 is of block of
threads 0, whose `.barrier` the barrier logs, and the two orders give grids that are not the same:
the barrier orders thread 1's store after thread 0's write in one and not in the other, so one
trace is racy and the other not. -/
theorem fire_twin : .barrier (ctxOf 1).who.cta ∈ fires.fired (Pending.launch 1) 0 ∧
    ∃ gk gf g₁ g₂, fires.advance ctxOf 1 = .ok (some gk) ∧
      fires.fire (Pending.launch 1) ctxOf 0 = .ok (some gf) ∧
      gk.fire (Pending.launch 1) ctxOf 0 = .ok (some g₁) ∧ gf.advance ctxOf 1 = .ok (some g₂) ∧
      ¬ g₁.Same g₂ :=
  ⟨by decide, _, _, _, _, rfl, rfl, rfl, rfl, fun h => absurd h.2.2.2.racy (by decide)⟩

/-- The callee of a shuffle, `i32 @llvm.nvvm.shfl.sync.bfly.i32`, its result in
`range(i32 0, 8)`. -/
def shflFn : Func :=
  { kernel #[] with
    name := "llvm.nvvm.shfl.sync.bfly.i32", ret := .int 32, retAttrs := [.range (.int 32) 0 8] }

/-- A thread at a statement whose result is register 0, so a value it is resumed with is there. -/
def regT : Thread := thread #[{ alloc with res := some 0 }]

/-- Register 0 of thread `k`'s innermost frame, if thread `k` runs. -/
def reg0 (g : Grid) (k : Nat) : Option Val :=
  match g.threads[k]? with
  | some (.run t) => t.frames.head?.bind (·.regs 0)
  | _ => none

/-- Thread 0 at `regT`, waiting at a butterfly shuffle of all lanes (mask `-1`) of `5` with lane
mask `0` and clamp `31`, and thread 1 at `storerAt 8 4`, on `Closed.mem1`. -/
def shfls : Grid :=
  { threads := #[.wait regT (.shfl .bfly) [.bits 32 (-1), .bits 32 5, .bits 32 0, .bits 32 31]
      shflFn, .run (storerAt 8 4)], mem := Closed.mem1 }

/-- The instance at a shuffle: with one thread per block of threads, thread 0's warp is thread 0
alone, so the shuffle completes, and thread 1's store and the shuffle give the same grid in both
orders; the shuffle logs nothing. -/
theorem shfl_diamond : ∃ gk gf g₁ g₂, shfls.advance ctxB 1 = .ok (some gk) ∧
    shfls.fire (Pending.launch 1) ctxB 0 = .ok (some gf) ∧
    gk.fire (Pending.launch 1) ctxB 0 = .ok (some g₁) ∧ gf.advance ctxB 1 = .ok (some g₂) ∧
    g₁.Same g₂ ∧ shfls.fired (Pending.launch 1) 0 = [] := by
  obtain ⟨gk, hk⟩ : ∃ gk, shfls.advance ctxB 1 = .ok (some gk) := ⟨_, rfl⟩
  obtain ⟨gf, hf⟩ : ∃ gf, shfls.fire (Pending.launch 1) ctxB 0 = .ok (some gf) := ⟨_, rfl⟩
  obtain ⟨g₁, g₂, h₁, h₂, h⟩ := Grid.advance_fire_comm hk hf (by decide)
  exact ⟨gk, gf, g₁, g₂, hk, hf, h₁, h₂, h, rfl⟩

/-- The shuffle of `shfls` puts in thread 0's register 0 the value `5` of its own lane, in the
range of its callee's return, and keeps thread 1's status. -/
theorem shfl_value : ∃ gf, shfls.fire (Pending.launch 1) ctxB 0 = .ok (some gf) ∧
    reg0 gf 0 = some (.bits 32 5) ∧ gf.threads[1]? = some (.run (storerAt 8 4)) :=
  ⟨_, rfl, rfl, rfl⟩

/-! ## A thread and a barrier from the start (`Grid.start_reach_fire_comm`) -/

/-- Two blocks of one thread. -/
def twoBlocks : Launch := ⟨fun | .x => 2 | _ => 1, fun _ => 1, 0⟩

/-- The launch of `Launch.k` (an `alloca`, a store, barrier 0 and `ret void`) on `twoBlocks`, on
the empty memory, with address choice and oracle 0. -/
def startB : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start Launch.prog Launch.k twoBlocks [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `startB`. -/
def runB : Grid × (Nat → Ctx) :=
  match startB with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, Launch.c)

/-- The contexts of `startB`. -/
def cB : Nat → Ctx := runB.2

/-- `g` after a step of thread `n`, or `g` if it takes none. -/
def advB (n : Nat) (g : Grid) : Grid :=
  match g.advance cB n with
  | .ok (some g') => g'
  | _ => g

/-- After thread 0's `alloca`. -/
def b1 : Grid := advB 0 runB.1
/-- After thread 0's store. -/
def b2 : Grid := advB 0 b1
/-- Thread 0 at the barrier. -/
def b3 : Grid := advB 0 b2
/-- After thread 1's `alloca`. -/
def b4 : Grid := advB 1 b3

/-- The launch `startB` starts, with the grid `runB.1` and contexts `cB`. -/
theorem startB_eq : startB = .ok (runB.1, cB) := rfl

/-- The four steps from the start to `b4`. -/
theorem b4_reach : Relation.ReflTransGen (Grid.Step twoBlocks cB) runB.1 b4 :=
  ((((Relation.ReflTransGen.refl).tail (b := runB.1) (c := b1) ⟨0, .inl rfl⟩).tail
    (c := b2) ⟨0, .inl rfl⟩).tail (c := b3) ⟨0, .inl rfl⟩).tail (c := b4) ⟨1, .inl rfl⟩

/-- The instance: in `b4` thread 0 waits at barrier 0, which completes, and thread 1's store
succeeds, so the two orders give the same grid. -/
theorem start_fire_diamond : ∃ t vs fn, b4.threads[0]? = some (.wait t .barrier vs fn) ∧
    ∃ gk gf g₁ g₂, b4.advance cB 1 = .ok (some gk) ∧ b4.fire twoBlocks cB 0 = .ok (some gf) ∧
      gk.fire twoBlocks cB 0 = .ok (some g₁) ∧ gf.advance cB 1 = .ok (some g₂) ∧ g₁.Same g₂ := by
  obtain ⟨t, vs, fn, hb⟩ : ∃ t vs fn, b4.threads[0]? = some (.wait t .barrier vs fn) :=
    ⟨_, _, _, rfl⟩
  obtain ⟨gk, hk⟩ : ∃ gk, b4.advance cB 1 = .ok (some gk) := ⟨_, rfl⟩
  obtain ⟨gf, hf⟩ : ∃ gf, b4.fire twoBlocks cB 0 = .ok (some gf) := ⟨_, rfl⟩
  obtain ⟨g₁, g₂, h₁, h₂, h⟩ := Grid.start_reach_fire_comm startB_eq b4_reach hk hf
  exact ⟨t, vs, fn, hb, gk, gf, g₁, g₂, hk, hf, h₁, h₂, h⟩

/-- The twin of the start's contexts: for every program, kernel, arguments, memory, address
choice and oracle, the start of `Pending.launch 1` does not give `fire_twin`'s contexts `ctxOf`,
since it puts thread 1 in block of threads 1 (`Grid.start_ctx`). So `fire_twin`'s grid in those
contexts is reachable from no start, and there the two orders differ. -/
theorem start_fire_twin {prog : Program} {fn : Func} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} :
    Grid.start prog fn (Pending.launch 1) args m ch oracle ≠ .ok (g, ctxOf) :=
  fun h => absurd (Grid.start_ctx h 1).2.1 (by decide)

/-! ## Two collective calls (`Grid.fire_fire_comm`, `Grid.start_fire_fire_comm`) -/

/-- Threads 0 and 1 at barrier 0 (`Pending.atBarrier`), on `Closed.mem1`. -/
def bars : Grid := { threads := #[atBarrier, atBarrier], mem := Closed.mem1 }

/-- Whether each thread runs. -/
def runs (g : Grid) : List Bool := g.threads.toList.map fun | .run _ => true | _ => false

/-- The instance of the second alternative: in the contexts `ctxB`, with one thread per block of
threads, the two barriers are of blocks of threads 0 and 1, the two fires give grids that differ
(each resumes its own thread), and each completes after the other, both orders giving the same
grid. -/
theorem bars_diamond : ∃ gn gj, bars.fire (Pending.launch 1) ctxB 0 = .ok (some gn) ∧
    bars.fire (Pending.launch 1) ctxB 1 = .ok (some gj) ∧ runs gn = [true, false] ∧
    runs gj = [false, true] ∧ ∃ g₁ g₂, gn.fire (Pending.launch 1) ctxB 1 = .ok (some g₁) ∧
      gj.fire (Pending.launch 1) ctxB 0 = .ok (some g₂) ∧ g₁.Same g₂ := by
  obtain ⟨gn, hn, rn⟩ : ∃ gn, bars.fire (Pending.launch 1) ctxB 0 = .ok (some gn) ∧
      runs gn = [true, false] := ⟨_, rfl, rfl⟩
  obtain ⟨gj, hj, rj⟩ : ∃ gj, bars.fire (Pending.launch 1) ctxB 1 = .ok (some gj) ∧
      runs gj = [false, true] := ⟨_, rfl, rfl⟩
  refine ⟨gn, gj, hn, hj, rn, rj,
    (Grid.fire_fire_comm (n := 0) (j := 1) rfl hn hj).resolve_left fun e => ?_⟩
  rw [e, rj] at rn
  cases rn

/-- The instance of the first alternative: in the contexts `ctxOf`, both threads are of block of
threads 0, and either thread's fire completes the barrier for both and gives one grid, in which no
fire completes, since no thread waits. -/
theorem bars_same : ∃ g', bars.fire (Pending.launch 2) ctxOf 0 = .ok (some g') ∧
    bars.fire (Pending.launch 2) ctxOf 1 = .ok (some g') ∧ runs g' = [true, true] :=
  ⟨_, rfl, rfl, rfl⟩

/-- Threads 0 and 1 at `regT`, waiting at a butterfly shuffle of all lanes with lane mask `1` and
clamp `31`, of `5` and `6`, on `Closed.mem1`. -/
def shfl2 : Grid :=
  { threads := #[.wait regT (.shfl .bfly) [.bits 32 (-1), .bits 32 5, .bits 32 1, .bits 32 31]
      shflFn, .wait regT (.shfl .bfly) [.bits 32 (-1), .bits 32 6, .bits 32 1, .bits 32 31] shflFn],
    mem := Closed.mem1 }

/-- The first alternative at a shuffle: in a launch of one block of two threads, lanes 0 and 1
share a warp, and either lane's fire completes the shuffle for both and gives one grid, in which
lane 0 has `6` and lane 1 has `5`. -/
theorem shfls_same : ∃ g', shfl2.fire (Pending.launch 2) ctxOf 0 = .ok (some g') ∧
    shfl2.fire (Pending.launch 2) ctxOf 1 = .ok (some g') ∧ reg0 g' 0 = some (.bits 32 6) ∧
    reg0 g' 1 = some (.bits 32 5) :=
  ⟨_, rfl, rfl, rfl, rfl⟩

/-- Thread `n` of block of threads 0, in `ctx0` with 64-bit pointers for thread 0 and 32-bit
pointers for every other thread. -/
def ctxL (n : Nat) : Ctx :=
  { ctxOf n with
    prog := if n = 0 then ctx0.prog else { ctx0.prog with layout := { ptrs := [(0, 32, 32)] } } }

/-- The callee of a shuffle of a pointer, its result `nonnull`. -/
def shflPtr : Func := { shflFn with ret := .ptr 0, retAttrs := [.flag "nonnull"] }

/-- Threads 0 and 1 at `regT`, waiting at a butterfly shuffle (`shflPtr`) of all lanes with lane
mask `0` of the pointer of block 0 at offset `2 ^ 32`, on `Closed.mem1`. -/
def ptrs : Grid :=
  let w : Status := .wait regT (.shfl .bfly) [.bits 32 (-1), .ptr ⟨0, 2 ^ 32⟩, .bits 32 0,
    .bits 32 31] shflPtr
  { threads := #[w, w], mem := Closed.mem1 }

/-- The twin of the premise on layouts: in the contexts `ctxL` the two threads have different
layouts, both fires complete, and neither alternative of the conclusion holds. The pointer's
address is `2 ^ 32` under thread 0's 64-bit layout and `0` under thread 1's 32-bit one, so
thread 0's fire gives thread 0 the pointer and thread 1's gives it poison (`nonnull`); after
thread 0's fire no thread waits, so thread 1's fire does not complete. -/
theorem layout_twin : (ctxL 0).prog.layout ≠ (ctxL 1).prog.layout ∧
    ∃ gn gj, ptrs.fire (Pending.launch 2) ctxL 0 = .ok (some gn) ∧
      ptrs.fire (Pending.launch 2) ctxL 1 = .ok (some gj) ∧
      ¬ (gn = gj ∨ ∃ g₁ g₂, gn.fire (Pending.launch 2) ctxL 1 = .ok (some g₁) ∧
        gj.fire (Pending.launch 2) ctxL 0 = .ok (some g₂) ∧ g₁.Same g₂) := by
  obtain ⟨gn, hn, pn, rn⟩ : ∃ gn, ptrs.fire (Pending.launch 2) ctxL 0 = .ok (some gn) ∧
      reg0 gn 0 = some (.ptr ⟨0, 2 ^ 32⟩) ∧ gn.fire (Pending.launch 2) ctxL 1 = .ok none :=
    ⟨_, rfl, rfl, rfl⟩
  obtain ⟨gj, hj, pj⟩ : ∃ gj, ptrs.fire (Pending.launch 2) ctxL 1 = .ok (some gj) ∧
      reg0 gj 0 = some .poison := ⟨_, rfl, rfl⟩
  refine ⟨fun e => absurd (congrArg Layout.ptrs e) (by decide), gn, gj, hn, hj, ?_⟩
  rintro (rfl | ⟨g₁, g₂, h₁, -⟩)
  · rw [pn] at pj
    cases pj
  · rw [rn] at h₁
    cases h₁

/-- After thread 1's store. -/
def b5 : Grid := advB 1 b4
/-- Threads 0 and 1 at barrier 0, of blocks of threads 0 and 1. -/
def b6 : Grid := advB 1 b5

/-- The instance from the start: `b6` is reachable from `startB`'s grid, and there the two
barriers complete, give grids that differ, and each completes after the other, both orders giving
the same grid. -/
theorem start_bars : Relation.ReflTransGen (Grid.Step twoBlocks cB) runB.1 b6 ∧
    ∃ gn gj, b6.fire twoBlocks cB 0 = .ok (some gn) ∧ b6.fire twoBlocks cB 1 = .ok (some gj) ∧
      runs gn = [true, false] ∧ runs gj = [false, true] ∧
      ∃ g₁ g₂, gn.fire twoBlocks cB 1 = .ok (some g₁) ∧ gj.fire twoBlocks cB 0 = .ok (some g₂) ∧
        g₁.Same g₂ := by
  obtain ⟨gn, hn, rn⟩ : ∃ gn, b6.fire twoBlocks cB 0 = .ok (some gn) ∧ runs gn = [true, false] :=
    ⟨_, rfl, rfl⟩
  obtain ⟨gj, hj, rj⟩ : ∃ gj, b6.fire twoBlocks cB 1 = .ok (some gj) ∧ runs gj = [false, true] :=
    ⟨_, rfl, rfl⟩
  refine ⟨(b4_reach.tail (c := b5) ⟨1, .inl rfl⟩).tail (c := b6) ⟨1, .inl rfl⟩, gn, gj, hn, hj, rn,
    rj, (Grid.start_fire_fire_comm startB_eq hn hj).resolve_left fun e => ?_⟩
  rw [e, rj] at rn
  cases rn

/-- The instance of `Mem.load_store_codec`: after thread 0 stores the `i32` 7 at offset 0 of block
1, its load of an `i32` there gives 7. -/
theorem store_load : ∃ m', (memOf [(1, blk 8 true)]).store {} ⟨0, 0⟩ 0 (.int 32) (.bits 32 7)
    ⟨1, 0⟩ (some 4) = .ok m' ∧ m'.load {} ⟨0, 0⟩ 0 (.int 32) ⟨1, 0⟩ (some 4) = .ok (.bits 32 7) :=
  have ⟨m', h⟩ : ∃ m', (memOf [(1, blk 8 true)]).store {} ⟨0, 0⟩ 0 (.int 32) (.bits 32 7)
      ⟨1, 0⟩ (some 4) = .ok m' := ⟨_, rfl⟩
  ⟨m', h, Mem.load_store_codec (Layout.Codec.int {} 32) 7 h rfl⟩

/-- The instance of `Mem.load_store` by another thread at another alignment: after thread 0's
store of `store_load`, thread 1's load of an `i32` there with alignment 2 gives 7. -/
theorem store_load_other : ∃ m', (memOf [(1, blk 8 true)]).store {} ⟨0, 0⟩ 0 (.int 32)
    (.bits 32 7) ⟨1, 0⟩ (some 4) = .ok m' ∧
      m'.load {} ⟨1, 0⟩ 0 (.int 32) ⟨1, 0⟩ (some 2) = .ok (.bits 32 7) :=
  have ⟨m', h⟩ : ∃ m', (memOf [(1, blk 8 true)]).store {} ⟨0, 0⟩ 0 (.int 32) (.bits 32 7)
      ⟨1, 0⟩ (some 4) = .ok m' := ⟨_, rfl⟩
  ⟨m', h, Mem.load_store_codec (Layout.Codec.int {} 32) 7 h rfl⟩

/-- The twin of `Mem.load_store`'s premise `hc`: in a block owned by thread 0, thread 0's store
succeeds, but thread 1's check fails before the store and its load faults after it. -/
theorem load_other : ∃ m', (memOf [(1, { blk 8 true with owner := .thread 0 })]).store {}
    ⟨0, 0⟩ 0 (.int 32) (.bits 32 7) ⟨1, 0⟩ (some 4) = .ok m' ∧
      m'.load {} ⟨1, 0⟩ 0 (.int 32) ⟨1, 0⟩ (some 4) =
        .error (.ub "access to another thread's or block's memory") :=
  ⟨_, rfl, rfl⟩

/-- The twin of `Mem.load_store`'s premise `hd`: a poison `i0` is stored as no bytes, which
decode to the `i0` 0, so the load after the store gives `bits 0 0` and not the stored poison. -/
theorem store_load_i0 : ∃ m', (memOf [(1, blk 8 true)]).store {} ⟨0, 0⟩ 0 (.int 0) .poison
    ⟨1, 0⟩ none = .ok m' ∧ m'.load {} ⟨0, 0⟩ 0 (.int 0) ⟨1, 0⟩ none = .ok (.bits 0 0) :=
  have ⟨m', h⟩ : ∃ m', (memOf [(1, blk 8 true)]).store {} ⟨0, 0⟩ 0 (.int 0) .poison
      ⟨1, 0⟩ none = .ok m' := ⟨_, rfl⟩
  ⟨m', h, Mem.load_store (bs := []) h rfl rfl (by simp [Layout.decode, Layout.scalarOf, ofLeBytes])⟩

/-- The instance of `Mem.load_scalar`: the `i32` load of `store_load` gives an `i32` scalar. -/
theorem load_scalar : ∃ m', (memOf [(1, blk 8 true)]).store {} ⟨0, 0⟩ 0 (.int 32) (.bits 32 7)
    ⟨1, 0⟩ (some 4) = .ok m' ∧ ∃ v, m'.load {} ⟨0, 0⟩ 0 (.int 32) ⟨1, 0⟩ (some 4) = .ok v ∧
      v.Scalar 32 :=
  have ⟨m', h, hl⟩ := store_load
  ⟨m', h, _, hl, Mem.load_scalar hl⟩

/-- The twin of `Mem.load_scalar`'s integer type: after a store of a pointer to block 1, a load
of a pointer type gives that pointer, which is no scalar. -/
theorem load_ptr : ∃ m', (memOf [(1, blk 8 true)]).store {} ⟨0, 0⟩ 0 (.ptr 0) (.ptr ⟨1, 0⟩)
    ⟨1, 0⟩ (some 8) = .ok m' ∧ m'.load {} ⟨0, 0⟩ 0 (.ptr 0) ⟨1, 0⟩ (some 8) = .ok (.ptr ⟨1, 0⟩) ∧
      ¬ (Val.ptr ⟨1, 0⟩).Scalar 64 :=
  have ⟨m', h⟩ : ∃ m', (memOf [(1, blk 8 true)]).store {} ⟨0, 0⟩ 0 (.ptr 0) (.ptr ⟨1, 0⟩)
      ⟨1, 0⟩ (some 8) = .ok m' := ⟨_, rfl⟩
  ⟨m', h, Mem.load_store h rfl rfl (by simp only [Layout.decode]; rfl), by simp [Val.Scalar]⟩

/-- The instance of `Layout.scalar_round`: an undefined `i32` round-trips through its bytes. -/
theorem undef_round : ∃ bs, ({} : Layout).encode (.int 32) .undef = some bs ∧
    ({} : Layout).decode (.int 32) bs = some .undef :=
  Layout.scalar_round (by decide) (.inr (.inr rfl))

/-- The twin of `Layout.scalar_round`'s premise `hw`: a poison `i0` is stored as no bytes, which
decode to `bits 0 0`, so it does not round-trip. -/
theorem poison_i0 : ¬ ∃ bs, ({} : Layout).encode (.int 0) .poison = some bs ∧
    ({} : Layout).decode (.int 0) bs = some .poison := by
  rintro ⟨bs, he, hd⟩
  simp only [Layout.encode, Option.some.injEq] at he
  subst he
  simp [Layout.decode, Layout.scalarOf, Layout.stored, Layout.storeSize, Layout.scalarBits,
    ofLeBytes] at hd

/-- The twin of `Layout.scalar_round`'s premise `hv`: a pointer, which is no scalar, has no bytes
at `i32`. -/
theorem ptr_i32 : ¬ ∃ bs, ({} : Layout).encode (.int 32) (.ptr ⟨1, 0⟩) = some bs ∧
    ({} : Layout).decode (.int 32) bs = some (.ptr ⟨1, 0⟩) := by
  rintro ⟨bs, he, -⟩
  simp [Layout.encode] at he

/-! ## Two updates of one operation (`Mem.update_comm`) -/

/-- Block 1 of 8 bytes of every thread, each 0. -/
def zeros : MojoProof.Sem.Block := { blk 8 true with bytes := fun _ => .byte 0 }

/-- The memory of block 1 `zeros`, with `next = 2`. -/
def memZ : Mem := { memOf [(1, zeros)] with next := 2 }

/-- Bytes 0 to 3 of `zeros` decode at `i32` to 0 (the integer codec). -/
theorem zeros_decode : ({} : Layout).decode (.int 32) (zeros.read 0 4) = some (.bits 32 0) := by
  rw [show zeros.read 0 4 = leBytes 4 (0 : BitVec 32).toNat from rfl]
  simp only [Layout.decode]
  exact Layout.scalarOf_leBytes 0 (by omega)

/-- Thread `n`'s `atomicrmw add` of `x` to the `i32` at offset 0 of block 1 of `memZ` succeeds:
the check succeeds, the bytes decode to 0, `rmw` and the encoding succeed (`Mem.update_eq_ok`). -/
theorem add_ok (n : Nat) (x : BitVec 32) : ∃ m', memZ.update {} ⟨n, 0⟩ 0
    (.int 32) .add (.bits 32 x) ⟨1, 0⟩ (some 4) = .ok m' :=
  ⟨_, Mem.update_eq_ok.2 ⟨zeros, .bits 32 0, _, _, rfl, rfl, zeros_decode, rfl, rfl, rfl⟩⟩

/-- The instance of `Mem.update_comm`: from `memZ`, thread 0's `atomicrmw add` of 1 and thread 1's
of 2 at offset 0 of block 1 each succeed, each succeeds after the other, and the two orders give
the same blocks, the same `next` and the same trace up to swaps. The twin of its one operation is
`MojoProofTest.Atomics.add_or` (an `add` and an `or` do not commute). -/
theorem update_comm : ∃ m₁ m₂ m₁₂ m₂₁,
    memZ.update {} ⟨0, 0⟩ 0 (.int 32) .add (.bits 32 1) ⟨1, 0⟩ (some 4) = .ok m₁ ∧
    memZ.update {} ⟨1, 0⟩ 0 (.int 32) .add (.bits 32 2) ⟨1, 0⟩ (some 4) = .ok m₂ ∧
    m₁.update {} ⟨1, 0⟩ 0 (.int 32) .add (.bits 32 2) ⟨1, 0⟩ (some 4) = .ok m₁₂ ∧
    m₂.update {} ⟨0, 0⟩ 0 (.int 32) .add (.bits 32 1) ⟨1, 0⟩ (some 4) = .ok m₂₁ ∧
    m₁₂.blocks = m₂₁.blocks ∧ m₁₂.next = m₂₁.next ∧ Trace.Same m₁₂.trace m₂₁.trace :=
  have ⟨m₁, h₁⟩ := add_ok 0 1
  have ⟨m₂, h₂⟩ := add_ok 1 2
  have ⟨m₁₂, m₂₁, h₁₂, h₂₁, hb, hn, ht⟩ := Mem.update_comm (by decide) h₁ h₂
  ⟨m₁, m₂, m₁₂, m₂₁, h₁, h₂, h₁₂, h₂₁, hb, hn, ht⟩

/-! ## Two `atomicrmw`s in the diamond (`Grid.advance_atomic_comm`, `Grid.advance_comm`) -/

/-- `atomicrmw op ptr %0, i32 o seq_cst`, its result unnamed. -/
def rmwOf (op : RmwOp) (o : Value) : Stmt :=
  { res := none, inst := .atomicrmw false op ⟨.ptr 0, .loc 0⟩ ⟨.int 32, o⟩ none .seqCst none }

/-- A thread at `rmwOf op o` with a pointer to block 1 in register 0. -/
def rmwAt (op : RmwOp) (o : Value) : Thread :=
  ⟨[{ frameAt 1 with fn := kernel #[rmwOf op o] }], 0⟩

/-- `rmwAt op o` after its step. -/
def rmwed (op : RmwOp) (o : Value) : Thread :=
  ⟨[{ frameAt 1 with fn := kernel #[rmwOf op o], pc := 1 }], 1⟩

/-- Thread 0 at an `atomicrmw add` of 1 and thread 1 at one of 2, on `memZ`. -/
def adds : Grid :=
  { threads := #[.run (rmwAt .add (.int 1)), .run (rmwAt .add (.int 2))], mem := memZ }

/-- `Stmt.checkAtomic` admits `rmwOf op o` in its kernel, for every operation `Stmt.checkAtomic`
admits. -/
theorem rmw_check (op : RmwOp) (hop : op.commutes = true) (o : Value) :
    (rmwOf op o).checkAtomic (kernel #[rmwOf op o]) = .ok () := by
  cases op <;> simp_all [Stmt.checkAtomic, rmwOf, RmwOp.commutes,
    Nat.nextPowerOfTwo_eq_self ⟨5, rfl⟩, pure, Except.pure]

/-- For every context, scope whose register 0 holds a pointer to block 1, step number, operation
`Stmt.checkAtomic` admits, operand `o` that evaluates at `i32` to `x`, and frame of `rmwOf op o`'s
kernel, the execution of `rmwOf op o` is, if `x` is a scalar of width 32 (bits of width 32, poison
or undef), the update of the `i32` at offset 0 of block 1 by `op` of `x`, then the frame at its next
statement, and otherwise `exec`'s fault at the operand. -/
theorem exec_rmw (c : Ctx) (s : Scope) (k : Nat) (f : Frame) (op : RmwOp) (o : Value) (x : Val)
    (hop : op.commutes = true) (hf : f.fn = kernel #[rmwOf op o])
    (hr : s.regs 0 = some (.ptr ⟨1, 0⟩)) (hx : evalV s (.int 32) o = .ok x) :
    exec c s k f (rmwOf op o) = if x.Scalar 32 then
      (s.mem.update c.prog.layout c.who 0 (.int 32) op x ⟨1, 0⟩ (some 4) >>=
        fun m' => pure (.next { f with pc := f.pc + 1 } m'))
    else throw (.unsupported "atomicrmw operand that is not a scalar of its type") := by
  have hi : (rmwOf op o).inst = .atomicrmw false op ⟨.ptr 0, .loc 0⟩ ⟨.int 32, o⟩ none
    .seqCst none := rfl
  have hmd : (rmwOf op o).checkMd = .ok () := rfl
  have hp : evalV s (.ptr 0) (.loc 0) = .ok (.ptr ⟨1, 0⟩) := by
    simp [evalV, hr, pure, Except.pure]
  have hq : Val.addr? (.ptr ⟨1, 0⟩) = .ok ⟨1, 0⟩ := rfl
  have hso : ((none : Option String).isNone && (Ordering.seqCst == Ordering.seqCst)) = true := rfl
  have h4 : c.prog.layout.storeSize (.int 32) = 4 := by
    simp [Layout.storeSize, Layout.scalarBits]
  have hb : c.prog.layout.scalarBits (.int 32) = 32 := by simp [Layout.scalarBits]
  by_cases hs : x.Scalar 32
  · simp only [Mem.update, bind_assoc, ite_eq_left hs]
    simp only [exec, hi, hmd, hf, rmw_check op hop o, hp, hq, hx, hb, decide_eq_true hs, h4, hso,
      Option.getD_none, bind, Except.bind, pure, Except.pure, ↓reduceIte]
  · simp only [ite_eq_right hs]
    simp only [exec, hi, hmd, hf, rmw_check op hop o, hp, hq, hx, hb, decide_eq_false hs, h4, hso,
      Option.getD_none, bind, Except.bind, pure, Except.pure, ↓reduceIte, Bool.false_eq_true]
    rfl

/-- `exec_rmw` for steps: for every context and memory, the step of `rmwAt op o`, if `o`
evaluates at `i32` to `x` in every scope with a pointer to block 1 in register 0, is, if `x` is a
scalar of width 32, the update, then `rmwed op o`, and otherwise the fault at the operand. -/
theorem step_rmw (c : Ctx) (m : Mem) (op : RmwOp) (o : Value) (x : Val)
    (hop : op.commutes = true)
    (hx : ∀ s : Scope, s.regs 0 = some (.ptr ⟨1, 0⟩) → evalV s (.int 32) o = .ok x) :
    step c (rmwAt op o) m = if x.Scalar 32 then
      (m.update c.prog.layout c.who 0 (.int 32) op x ⟨1, 0⟩ (some 4) >>=
        fun m' => pure (.next (rmwed op o) m'))
    else throw (.unsupported "atomicrmw operand that is not a scalar of its type") := by
  show exec c (c.scope m _ 0) 0 _ (rmwOf op o) >>= _ = _
  rw [exec_rmw _ _ _ _ op o x hop rfl rfl (hx _ rfl)]
  simp only [Ctx.scope]
  split
  · cases m.update c.prog.layout c.who 0 (.int 32) op x ⟨1, 0⟩ (some 4) <;> rfl
  · rfl

/-- Thread `n` of `adds` has pending a write, then a read, of the 4 bytes at offset 0 of block 1,
both by an `atomicrmw add`. -/
theorem adds_pending (n : Nat) (hn : n < 2) : adds.pending ctxOf n =
    [.access ⟨⟨n, 0⟩, ⟨1, 0⟩, 4, true, some .add, false⟩,
     .access ⟨⟨n, 0⟩, ⟨1, 0⟩, 4, false, some .add, false⟩] := by
  rcases n with _ | _ | n <;> first | rfl | omega

/-- `step_rmw` for grids: for every grid whose thread `n` is at `rmwAt op o`, an operation
`Stmt.checkAtomic` admits, with `o` evaluating at `i32` to a scalar `x` of width 32, in the contexts
`ctxOf`, the thread's step is the update of the grid's memory, if it succeeds, and then `rmwed op
o`. -/
theorem advance_rmw {g : Grid} {n : Nat} {op : RmwOp} {o : Value} {x : Val} {m' : Mem}
    (hop : op.commutes = true) (ht : g.threads[n]? = some (.run (rmwAt op o)))
    (hx : ∀ s : Scope, s.regs 0 = some (.ptr ⟨1, 0⟩) → evalV s (.int 32) o = .ok x)
    (hs : x.Scalar 32) (hm : g.mem.update {} ⟨n, 0⟩ 0 (.int 32) op x ⟨1, 0⟩ (some 4) = .ok m') :
    g.advance ctxOf n =
      .ok (some { threads := g.threads.set! n (.run (rmwed op o)), mem := m' }) := by
  unfold Grid.advance
  rw [ht]
  simp only [step_rmw _ _ op _ _ hop hx, ite_eq_left hs, show (ctxOf n).prog.layout = {} from rfl,
    show (ctxOf n).who = ⟨n, 0⟩ from rfl, hm]
  rfl

/-- The fault of `step_rmw` for grids: for every grid whose thread `n` is at `rmwAt op o`, an
operation `Stmt.checkAtomic` admits, with `o` evaluating at `i32` to `x`, not a scalar of width 32,
in the contexts `ctxOf`, the thread's step faults at the operand, whatever the grid's memory. -/
theorem advance_rmw_fault {g : Grid} {n : Nat} {op : RmwOp} {o : Value} {x : Val}
    (hop : op.commutes = true) (ht : g.threads[n]? = some (.run (rmwAt op o)))
    (hx : ∀ s : Scope, s.regs 0 = some (.ptr ⟨1, 0⟩) → evalV s (.int 32) o = .ok x)
    (hs : ¬ x.Scalar 32) :
    g.advance ctxOf n =
      .error (.unsupported "atomicrmw operand that is not a scalar of its type") := by
  unfold Grid.advance
  rw [ht]
  simp only [step_rmw _ _ op _ _ hop hx, ite_eq_right hs]
  rfl

/-- The steps of both threads of `adds` succeed (`advance_rmw`, `add_ok`). -/
theorem adds_ok (n : Nat) (hn : n < 2) : ∃ g', adds.advance ctxOf n = .ok (some g') :=
  have ⟨_, hm⟩ := add_ok n (BitVec.ofInt 32 ((n : Int) + 1))
  ⟨_, advance_rmw (o := .int ((n : Int) + 1)) rfl
    (by rcases n with _ | _ | n <;> first | rfl | omega)
    (fun _ _ => by simp [evalV, pure, Except.pure]) (.inl ⟨_, rfl⟩) hm⟩

/-- `rmwAt op o` names only blocks 0 and 1. -/
theorem rmwAt_namesIn (op : RmwOp) (o : Value) : (rmwAt op o).NamesIn (· < 2) := by
  intro f hf r x hr
  simp only [rmwAt, List.mem_singleton] at hf
  subst hf
  simp only [frameAt] at hr
  split at hr
  · cases hr
    simp [Val.NamesIn]
  · cases hr

/-- `adds` is closed in the contexts `ctxOf`. -/
theorem adds_closed : adds.Closed ctxOf :=
  closed_of (fun _ _ => rfl) (fun _ _ _ => nofun) fun n s hs => by
    rcases n with _ | _ | n <;> simp at hs <;> subst hs <;> exact rmwAt_namesIn _ _

/-- `adds` has its frames' `alloca`s owned by their threads (it has none). -/
theorem adds_owns : adds.Owns ctxOf := fun n s hs => by
  rcases n with _ | _ | n <;> simp [adds] at hs <;> subst hs <;>
    simp [Status.AllocasIn, rmwAt, frameAt]

/-- The instance of `Grid.advance_atomic_comm`: on `adds` (closed), threads 0 and 1 have pending
writes by `atomicrmw add`s at offset 0 of block 1, of 4 bytes each; from steps of the two threads
that succeed (`adds_ok`), the other thread's step succeeds and the two orders give the same grid. -/
theorem atomic_comm {gn gk : Grid} (hn : adds.advance ctxOf 0 = .ok (some gn))
    (hk : adds.advance ctxOf 1 = .ok (some gk)) :
    ∃ g₁ g₂, gn.advance ctxOf 1 = .ok (some g₁) ∧ gk.advance ctxOf 0 = .ok (some g₂) ∧
      g₁.Same g₂ :=
  Grid.advance_atomic_comm adds_closed (by decide) hn hk
    (a := ⟨⟨0, 0⟩, ⟨1, 0⟩, 4, true, some .add, false⟩)
    (a' := ⟨⟨1, 0⟩, ⟨1, 0⟩, 4, true, some .add, false⟩)
    (by rw [adds_pending 0 (by decide)]; exact List.mem_cons_self)
    (by rw [adds_pending 1 (by decide)]; exact List.mem_cons_self) rfl rfl rfl rfl

/-- The instance of `Grid.advance_comm`'s premise at two `atomicrmw`s: on `adds` the writes of the
two threads overlap, and no pending access of thread 0 conflicts with one of thread 1, as
`Access.conflict` exempts two `atomicrmw`s of one operation at one pointer and size; and with the
premise the two orders give the same grid. -/
theorem atomic_diamond :
    (∃ a a', .access a ∈ adds.pending ctxOf 0 ∧ .access a' ∈ adds.pending ctxOf 1 ∧
      a.write = true ∧ a.overlaps a' = true) ∧
    (∀ a a', .access a ∈ adds.pending ctxOf 0 → .access a' ∈ adds.pending ctxOf 1 →
      a.conflict a' = false) ∧
    ∃ gn gk g₁ g₂, adds.advance ctxOf 0 = .ok (some gn) ∧ adds.advance ctxOf 1 = .ok (some gk) ∧
      gn.advance ctxOf 1 = .ok (some g₁) ∧ gk.advance ctxOf 0 = .ok (some g₂) ∧ g₁.Same g₂ :=
  have hW : ∀ a a', .access a ∈ adds.pending ctxOf 0 → .access a' ∈ adds.pending ctxOf 1 →
      a.conflict a' = false := fun a a' ha ha' => by
    rw [adds_pending 0 (by decide)] at ha
    rw [adds_pending 1 (by decide)] at ha'
    simp only [List.mem_cons, List.not_mem_nil, or_false, Event.access.injEq] at ha ha'
    rcases ha with rfl | rfl <;> rcases ha' with rfl | rfl <;> decide
  have ⟨gn, hn⟩ := adds_ok 0 (by decide)
  have ⟨gk, hk⟩ := adds_ok 1 (by decide)
  have ⟨g₁, g₂, h₁, h₂, h⟩ := Grid.advance_comm adds_closed adds_owns (by decide) hn hk hW
  ⟨⟨⟨⟨0, 0⟩, ⟨1, 0⟩, 4, true, some .add, false⟩, ⟨⟨1, 0⟩, ⟨1, 0⟩, 4, true, some .add, false⟩,
    by rw [adds_pending 0 (by decide)]; exact List.mem_cons_self,
    by rw [adds_pending 1 (by decide)]; exact List.mem_cons_self, rfl, by decide⟩, hW,
    gn, gk, g₁, g₂, hn, hk, h₁, h₂, h⟩

end MojoProofTest.Confluence
