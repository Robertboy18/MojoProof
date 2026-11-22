import MojoProof.Sem.Writes

/-!
# A launch of `alloca`, `store`, a barrier and `ret`

The kernel `k` is

    %0 = alloca i32
    store i32 7, ptr %0
    call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
    ret void

with the barrier declared `convergent`. Launched on one thread on the empty memory, with address
choice and oracle 0, it starts (`start_eq`), and five steps of `Grid.Step` run it (`steps`): the
`alloca` makes block 2 (`g1`), the store writes 4 bytes there (`g2`), the call waits at the
barrier (`g3`), the barrier completes (`g4`) and the return makes block 2 dead (`g5`). Every grid
reachable from the start is closed, has its frames' `alloca`s owned by their threads and its
waiting threads at their calls (`reach`, by `Grid.start_reach_closed`, `Grid.reach_owns` and
`Grid.start_reach_atCalls`). On this run these say something: the frame of thread 0 lists block 2
among its `alloca`s while it runs and while it waits, and thread 0 owns block 2 (`owns`); in `g3`
thread 0 waits at the barrier and is at its call (`waits`); the store and the return change the
memory only as `Mem.Changes` allows, the store logging its write and the return making block 2
dead (`changes`, by `Grid.start_reach_changes`). The negative twins are `Writes.owns_twin` and
`Closed.atCalls_twin`. Statements about this launch, not about every launch.
-/

namespace MojoProofTest.Launch

open MojoProof.Sem MojoProof.LLVM

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The name of the barrier intrinsic. -/
def barrierName : String := "llvm.nvvm.barrier.cta.sync.aligned.all"

/-- `declare void @llvm.nvvm.barrier.cta.sync.aligned.all(i32) #0`. -/
def barrierDecl : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := barrierName,
    params := [⟨.int 32, [], none⟩], group := some 0, names := #[], blocks := #[] }

/-- `%0 = alloca i32`, `store i32 7, ptr %0`, `call void @llvm.nvvm.barrier...(i32 0)`. -/
def body : Array Stmt :=
  #[{ res := some 0, inst := .alloca (.int 32) none none },
    { res := none, inst := .store false ⟨.int 32, .int 7⟩ ⟨.ptr 0, .loc 0⟩ none },
    { res := none, inst := .call {} .void (.fn barrierName) [(⟨.int 32, .int 0⟩, [])] }]

/-- The kernel `@k`: `body`, then `ret void`. -/
def k : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "k", params := [],
    group := none, names := #["entry"], blocks := #[⟨0, body, .ret none⟩] }

/-- The module of `k` and the barrier, with attribute group 0 `convergent`. -/
def md : Module :=
  { (default : Module) with funcs := #[k, barrierDecl], attrGroups := #[(0, [.flag "convergent"])] }

/-- The program of `md`, with the default data layout. -/
def prog : Program :=
  { module := md, sha256 := "", layout := {}, intrinsics := [(barrierName, .barrier)],
    kernels := ["k"] }

/-- The launch of `k` on one thread on the empty memory, with address choice and oracle 0. -/
def start : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start prog k .one [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `start`. -/
def run0 : Grid × (Nat → Ctx) :=
  match start with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ⟨prog, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩, fun _ => 0,
      fun _ => 0⟩)

/-- The start's grid. -/
def g0 : Grid := run0.1

/-- The start's contexts. -/
def c : Nat → Ctx := run0.2

/-- `g` after a step of thread 0, or `g` if it takes none. -/
def adv (g : Grid) : Grid :=
  match g.advance c 0 with
  | .ok (some g') => g'
  | _ => g

/-- `g` after the collective call thread 0 waits at completes, or `g` if it does not. -/
def fire (g : Grid) : Grid :=
  match g.fire .one c 0 with
  | .ok (some g') => g'
  | _ => g

/-- After the `alloca`. -/
def g1 : Grid := adv g0
/-- After the store. -/
def g2 : Grid := adv g1
/-- At the barrier. -/
def g3 : Grid := adv g2
/-- After the barrier. -/
def g4 : Grid := fire g3
/-- After the return. -/
def g5 : Grid := adv g4

/-- The launch starts, with grid `g0` and contexts `c`. -/
theorem start_eq : start = .ok (g0, c) := rfl

/-- The five steps of the run: four steps of thread 0 and the barrier. -/
theorem steps :
    g0.advance c 0 = .ok (some g1) ∧ g1.advance c 0 = .ok (some g2) ∧
      g2.advance c 0 = .ok (some g3) ∧ g3.fire .one c 0 = .ok (some g4) ∧
      g4.advance c 0 = .ok (some g5) :=
  ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- `g1` is reachable from the start. -/
theorem reach1 : Relation.ReflTransGen (Grid.Step .one c) g0 g1 := .single ⟨0, .inl steps.1⟩
/-- `g2` is reachable from the start. -/
theorem reach2 : Relation.ReflTransGen (Grid.Step .one c) g0 g2 :=
  reach1.tail ⟨0, .inl steps.2.1⟩
/-- `g3` is reachable from the start. -/
theorem reach3 : Relation.ReflTransGen (Grid.Step .one c) g0 g3 :=
  reach2.tail ⟨0, .inl steps.2.2.1⟩
/-- `g4` is reachable from the start. -/
theorem reach4 : Relation.ReflTransGen (Grid.Step .one c) g0 g4 :=
  reach3.tail ⟨0, .inr steps.2.2.2.1⟩

/-- Every grid reachable from the start is closed, has its frames' `alloca`s owned by their
threads and its waiting threads at their calls. -/
theorem reach (g' : Grid) (h : Relation.ReflTransGen (Grid.Step .one c) g0 g') :
    g'.Closed c ∧ g'.Owns c ∧ g'.AtCalls c :=
  ⟨Grid.start_reach_closed start_eq (fun _ _ _ _ _ h => by cases h) h,
    Grid.reach_owns h (Grid.start_owns start_eq c), Grid.start_reach_atCalls start_eq h⟩

/-- `Grid.Owns` on the run: the frame of thread 0 lists block 2 among its `alloca`s after the
`alloca` (running) and at the barrier (waiting), and thread 0 owns block 2 there. -/
theorem owns :
    (∃ t, g1.threads[0]? = some (.run t) ∧ t.frames.map (·.allocas) = [[2]] ∧
      g1.mem.Owned (c 0).who.thread 2) ∧
    ∃ t args fn, g3.threads[0]? = some (.wait t .barrier args fn) ∧
      t.frames.map (·.allocas) = [[2]] ∧ g3.mem.Owned (c 0).who.thread 2 := by
  refine ⟨⟨_, rfl, rfl, ?_⟩, ⟨_, _, _, rfl, rfl, ?_⟩⟩
  · exact (reach g1 reach1).2.1 0 _ rfl _ List.mem_cons_self 2 List.mem_cons_self
  · exact (reach g3 reach3).2.1 0 _ rfl _ List.mem_cons_self 2 List.mem_cons_self

/-- `Grid.AtCalls` on the run: in `g3` thread 0 waits at the barrier and is at its call of the
barrier's declaration. -/
theorem waits :
    ∃ t args, g3.threads[0]? = some (.wait t .barrier args barrierDecl) ∧
      t.AtCall (c 0) .barrier barrierDecl := by
  refine ⟨_, _, rfl, ?_⟩
  exact (reach g3 reach3).2.2 0 _ rfl

/-- L1b on the run: the store changes the memory only as `Mem.Changes` allows with `L` the blocks
thread 0 owns, and logs its write of 4 bytes at block 2; the return does too, and makes block 2
dead. -/
theorem changes :
    g1.mem.Changes (g1.mem.Owned (c 0).who.thread) (· = g1.mem.fresh (c 0).who.thread 1)
        g2.mem ∧
      g2.mem.trace = [.access ⟨⟨0, 0⟩, ⟨2, 0⟩, 4, true, none, false⟩] ∧
      g4.mem.Changes (g4.mem.Owned (c 0).who.thread) (· = g4.mem.fresh (c 0).who.thread 3)
        g5.mem ∧
      g5.threads[0]? = some .done ∧ (g5.mem.blocks 2).map (·.live) = some false :=
  ⟨Grid.start_reach_changes (t := ⟨_, 1⟩) start_eq reach1 rfl steps.2.1, rfl,
    Grid.start_reach_changes (t := ⟨_, 3⟩) start_eq reach4 rfl steps.2.2.2.2, rfl, rfl⟩

end MojoProofTest.Launch
