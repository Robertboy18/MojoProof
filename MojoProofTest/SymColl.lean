import MojoProofTest.Confluence
import MojoProof.Sym.CanonBar
import MojoProof.Sym.WarpRoute
import MojoProofTest.KernelRfl

/-!
# A canonical run through a barrier and two butterfly shuffles, on a concrete launch

Instances of `PhaseRun.start_sound`, `BlockRun` and `BlockBar` (MojoProof/Sym/CanonBar.lean), of
`WarpRun.of_waits` (MojoProof/Sym/Canon.lean) through `warp_route` and `WarpRun.shfl_of`
(MojoProof/Sym/WarpRoute.lean), of `WarpShfl` (MojoProof/Sym/Canon.lean), and of
`Seq.ToWait.of_runTo`, `Seq.of_runTo`, `ToWait.of_runTo`, `Runs.of_runTo` and
`bflyRoundsAt_of_shfl` (MojoProof/Sym/SchedWait.lean). The kernel `kern` is

    %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
    call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
    %1 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %0, i32 1, i32 31)
    %2 = add i32 %0, %1
    %3 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %2, i32 2, i32 31)
    %4 = add i32 %2, %3
    ret void

with the barrier and the shuffle declared `convergent`, launched on one block of four threads
(`launch2 1 1 4 1`, one warp) on the empty memory, with address choice and oracle 0.

* `sound`: the launch is sound (`Grid.Sound`), by `PhaseRun.start_sound` at the run of its one
  block (`BlockRun`): the warp's lanes in turn to the barrier (`WarpWait.waits`) and the barrier
  (`hb1`, a `BlockBar`); then the warp through the two shuffles to the returns (`warp`, a
  `WarpRun`, by `warp_route`): each lane's run through its two waits (`lane`, as `runTo` computes
  it), and the shuffles' deliveries, each lane resumed with `shflSource`'s lane's `%0` and then
  `%2`, checked by the kernel (`shfls`, `Piece.Wait.shflOk`, for `WarpRun.shfl_of`).
* `lanes`: at its return each lane `l` holds in `%4` the value of the butterfly rounds at offsets
  1 and 2 over the lanes' thread numbers (`bflyRounds (· + ·) [1, 2] (fun l => l) l`, by
  `bflyRoundsAt_of_shfl`), which is 6 (`lanes_six`).
* `hw2`, `hw3`, `hs4`, `hx2`, `hx3`: the statements at 67bd004, with that commit's `m2`, `m3`,
  `fin` and `u3` unfolded: the threads in turn to each shuffle and to their returns, as `runTo`
  computes them, and the two shuffles (`WarpShfl`) at those statuses; with `m1_eq`, the memories
  the threads' runs past the barrier leave are `m1`. Tests of `Seq.ToWait.of_runTo`,
  `Seq.of_runTo` and `WarpShfl`: `lane` and `warp` do not give them, since a wait
  (`Piece.Wait.via`) does not state the thread it waits from or the callee, and `WarpRun`'s
  statuses are existential.
* The open-goal twin (an `example` with `#guard_msgs`): `warp` without the shuffles' checks
  (`shfls`) leaves `WarpRun.of_waits`' premise on the shuffles as the goal.

Statements about this launch, not about every launch.
-/

namespace MojoProofTest.SymColl

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The name of the butterfly shuffle intrinsic. -/
def shflName : String := "llvm.nvvm.shfl.sync.bfly.i32"

/-- `declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()`. -/
def tidDecl : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .int 32,
    name := "llvm.nvvm.read.ptx.sreg.tid.x", params := [], group := none, names := #[],
    blocks := #[] }

/-- `declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #0`. -/
def shflDecl : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .int 32, name := shflName,
    params := List.replicate 4 ⟨.int 32, [], none⟩, group := some 0, names := #[],
    blocks := #[] }

/-- `call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %a, i32 o, i32 31)`. -/
def shflCall (a : Nat) (o : Int) : Inst :=
  .call {} (.int 32) (.fn shflName) [(⟨.int 32, .int (-1)⟩, []), (⟨.int 32, .loc a⟩, []),
    (⟨.int 32, .int o⟩, []), (⟨.int 32, .int 31⟩, [])]

/-- The statements of `kern`'s one block. -/
def body : Array Stmt :=
  #[{ res := some 0, inst := .call {} (.int 32) (.fn tidDecl.name) [] },
    { res := none, inst := .call {} .void (.fn Launch.barrierName) [(⟨.int 32, .int 0⟩, [])] },
    { res := some 1, inst := shflCall 0 1 },
    { res := some 2, inst := .bin .add {} (.int 32) (.loc 0) (.loc 1) },
    { res := some 3, inst := shflCall 2 2 },
    { res := some 4, inst := .bin .add {} (.int 32) (.loc 2) (.loc 3) }]

/-- The kernel `@k`: `body`, then `ret void`. -/
def kern : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "k", params := [],
    group := none, names := #["entry"], blocks := #[⟨0, body, .ret none⟩] }

/-- The module of `kern` and the three intrinsics, with attribute group 0 `convergent`. -/
def md : Module :=
  { (default : Module) with
    funcs := #[kern, tidDecl, Launch.barrierDecl, shflDecl]
    attrGroups := #[(0, [.flag "convergent"])] }

/-- The program of `md`, with the default data layout. -/
def prog : Program :=
  { module := md, sha256 := "", layout := {},
    intrinsics := [(tidDecl.name, .sreg .tid .x), (Launch.barrierName, .barrier),
      (shflName, .shfl .bfly)],
    kernels := ["k"] }

/-- One block of four threads. -/
def L : Launch := launch2 1 1 4 1

/-- The launch of `kern` on `L`, on the empty memory, with address choice and oracle 0. -/
def start : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start prog kern L [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `start`. -/
def run0 : Grid × (Nat → Ctx) :=
  match start with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, Launch.c)

/-- The start's grid. -/
def g0 : Grid := run0.1

/-- The start's contexts. -/
def c : Nat → Ctx := run0.2

/-- The launch starts, with grid `g0` and contexts `c`. -/
theorem start_eq : start = .ok (g0, c) := rfl

/-- Thread `n`'s run in `c n` from `t` on `m` to its next wait or return, in at most 4 steps
(`runTo`); `t` on `m` returning to `m` if it does not get there. -/
def next (n : Nat) (t : Thread) (m : Mem) : Thread × Mem × Step :=
  (runTo (c n) 4 t m).getD (t, m, .done m)

/-- The memory after threads `0` to `k - 1` run in turn by `next`, each from its thread `t n`,
the first on `m`: what a run to a wait leaves, or what a return leaves. -/
def memAt (t : Nat → Thread) (m : Mem) : Nat → Mem
  | 0 => m
  | k + 1 =>
    match next k (t k) (memAt t m k) with
    | (_, _, .done m') => m'
    | (_, m₁, _) => m₁

/-- The thread thread `n` stops at in the turns of `memAt t m`. -/
def stop (t : Nat → Thread) (m : Mem) (n : Nat) : Thread := (next n (t n) (memAt t m n)).1

/-- The threads at the barrier. -/
def u1 : Nat → Thread := stop (Grid.thread g0) g0.mem

/-- The memory after the barrier of block 0. -/
def m1 : Mem :=
  (List.range 1).foldl (fun m b => m.log (.barrier b)) (memAt (Grid.thread g0) g0.mem 4)

/-- The threads past the barrier. -/
def t1 (n : Nat) : Thread := (u1 n).resume none

/-- The threads at the first shuffle. -/
def u2 : Nat → Thread := stop t1 m1

/-- Lane `n`'s `%1`, what the first shuffle gives it: lane `n ^^^ 1`'s `%0`. -/
def r2 (n : Nat) : Option Val := some (.bits 32 (BitVec.ofNat 32 (n ^^^ 1)))

/-- The threads past the first shuffle. -/
def t2 (n : Nat) : Thread := (u2 n).resume (r2 n)

/-- The threads at the second shuffle (no lane changes the memory past the barrier). -/
def u3 : Nat → Thread := stop t2 m1

/-- Lane `n`'s `%2`, the value it offers at the second shuffle. -/
def a3 (n : Nat) : Val := .bits 32 (BitVec.ofNat 32 (n + (n ^^^ 1)))

/-- Lane `n`'s `%3`, what the second shuffle gives it: lane `n ^^^ 2`'s `%2`. -/
def r3 (n : Nat) : Option Val := some (.bits 32 (BitVec.ofNat 32 ((n ^^^ 2) + (n ^^^ 2 ^^^ 1))))

/-- The threads past the second shuffle. -/
def t3 (n : Nat) : Thread := (u3 n).resume (r3 n)

/-- The threads at their returns. -/
def u4 : Nat → Thread := stop t3 m1

-- Each phase's runs are stated from `memAt`'s first memory rewritten (`memAt.eq_1`) rather than
-- unified with it: the elaborator would compare `memAt t m 0` with the previous phase's memory by
-- evaluating the phases before it.

/-- The threads in turn to the barrier. -/
theorem hw1 : ∃ Es, Seq.ToWait c (Grid.thread g0)
    (fun n => .wait (u1 n) .barrier [.bits 32 0] Launch.barrierDecl) (List.range 4) g0.mem Es
    (memAt (Grid.thread g0) g0.mem 4) := by
  obtain ⟨Es, h⟩ := Seq.ToWait.of_runTo (c := c) (t := Grid.thread g0) (N := 4) (fuel := 4)
    (s := fun n => .wait (u1 n) .barrier [.bits 32 0] Launch.barrierDecl)
    (mem := memAt (Grid.thread g0) g0.mem) fun k hk => by
      refine ⟨_, _, _, _, rfl, ?_⟩
      interval_cases k <;> kernel_rfl
  rw [memAt.eq_1] at h
  exact ⟨Es, h⟩

/-- **The memories past the barrier are `m1`**: no lane changes the memory past the barrier, so
the four threads' runs in turn from `t1` on `m1`, then from `t2` on what they leave, then from
the threads past the second shuffle on what those leave, each leave `m1`, by the kernel. These
are the bodies of `m2`, `m3` and `fin` at 67bd004 (`memAt t1 m1 4`, `memAt t2 m2 4`,
`memAt t3 m3 4`, with that commit's `u3 := stop t2 m2` in `t3`), so that commit's `u3` and `u4`
(`stop t2 m2`, `stop t3 m3`) are `u3` and `u4`. -/
theorem m1_eq : memAt t1 m1 4 = m1 ∧ memAt t2 (memAt t1 m1 4) 4 = m1 ∧
    memAt (fun n => (stop t2 (memAt t1 m1 4) n).resume (r3 n)) (memAt t2 (memAt t1 m1 4) 4) 4 =
      m1 :=
  ⟨by kernel_rfl, by kernel_rfl, by kernel_rfl⟩

/-- **The threads in turn to the first shuffle** (`hw2` at 67bd004, its `m2` unfolded), as
`runTo` computes them (`Seq.ToWait.of_runTo`): thread `n` from `t1 n` on the memory the threads
before it leave waits at the shuffle offering its thread number, from `u2 n`, with callee
`shflDecl`. A test of `Seq.ToWait.of_runTo`; `lane` does not give it, since its waits
(`Piece.Wait.via`) state each lane's position, call, arguments and memory, not the thread it
waits from (`u2 n`) or the callee, and it runs each lane from `m1`, not in turn. -/
theorem hw2 : ∃ Es, Seq.ToWait c t1
    (fun n => .wait (u2 n) (.shfl .bfly)
      [.bits 32 (-1), .bits 32 (.ofNat 32 n), .bits 32 1, .bits 32 31] shflDecl)
    (List.range 4) m1 Es (memAt t1 m1 4) := by
  obtain ⟨Es, h⟩ := Seq.ToWait.of_runTo (c := c) (t := t1) (N := 4) (fuel := 4)
    (s := fun n => .wait (u2 n) (.shfl .bfly)
      [.bits 32 (-1), .bits 32 (.ofNat 32 n), .bits 32 1, .bits 32 31] shflDecl)
    (mem := memAt t1 m1) fun k hk => ⟨_, _, _, _, rfl, by interval_cases k <;> kernel_rfl⟩
  exact ⟨Es, memAt.eq_1 t1 m1 ▸ h⟩

/-- **The threads in turn to the second shuffle** (`hw3` at 67bd004, its `m2`, `m3` and `u3`
unfolded), as `runTo` computes them: thread `n` from `t2 n` waits at the shuffle offering
`a3 n`, from `stop t2 (memAt t1 m1 4) n`, with callee `shflDecl`; by `m1_eq`, the runs from `t2`
on `m1`. A test of `Seq.ToWait.of_runTo`; `lane` does not give it, as for `hw2`. -/
theorem hw3 : ∃ Es, Seq.ToWait c t2
    (fun n => .wait (stop t2 (memAt t1 m1 4) n) (.shfl .bfly)
      [.bits 32 (-1), a3 n, .bits 32 2, .bits 32 31] shflDecl)
    (List.range 4) (memAt t1 m1 4) Es (memAt t2 (memAt t1 m1 4) 4) := by
  rw [m1_eq.1]
  obtain ⟨Es, h⟩ := Seq.ToWait.of_runTo (c := c) (t := t2) (N := 4) (fuel := 4)
    (s := fun n => .wait (u3 n) (.shfl .bfly) [.bits 32 (-1), a3 n, .bits 32 2, .bits 32 31]
      shflDecl) (mem := memAt t2 m1) fun k hk =>
      ⟨_, _, _, _, rfl, by interval_cases k <;> kernel_rfl⟩
  exact ⟨Es, memAt.eq_1 t2 m1 ▸ h⟩

/-- **The threads in turn to their returns** (`hs4` at 67bd004, its `t3`, `m3` and `fin`
unfolded), as `runTo` computes them (`Seq.of_runTo`); by `m1_eq`, the runs from `t3` on `m1`. A
test of `Seq.of_runTo`; `lane` does not give it: its runs to the returns are from the threads its
waits reach, which it does not state, and from `m1`, not in turn. -/
theorem hs4 : ∃ Es, Seq c (fun n => (stop t2 (memAt t1 m1 4) n).resume (r3 n)) (List.range 4)
    (memAt t2 (memAt t1 m1 4) 4) Es
    (memAt (fun n => (stop t2 (memAt t1 m1 4) n).resume (r3 n)) (memAt t2 (memAt t1 m1 4) 4)
      4) := by
  rw [m1_eq.2.1, m1_eq.1]
  obtain ⟨Es, h⟩ := Seq.of_runTo (c := c) (t := t3) (N := 4) (fuel := 4) (mem := memAt t3 m1)
    fun k hk => ⟨(next k (t3 k) (memAt t3 m1 k)).1, (next k (t3 k) (memAt t3 m1 k)).2.1, by
      interval_cases k <;> kernel_rfl⟩
  exact ⟨Es, memAt.eq_1 t3 m1 ▸ h⟩

/-- The warp of first thread 0 is the block's four threads. -/
theorem warp0 : warpThreads L 0 = List.range 4 := by decide

/-- The barrier (`BlockBar`): every thread of block 0 waits from `u1` at the barrier of number 0,
at the instruction of thread 0. -/
theorem hb1 : BlockBar L 0 (fun n => .wait (u1 n) .barrier [.bits 32 0] Launch.barrierDecl) u1 :=
  ⟨fun _ => .bits 32 0, fun _ => Launch.barrierDecl, 0, by decide, fun n hn => by
    have hn : n < 4 := by
      have h4 : volume L.block = 4 := rfl
      rw [h4] at hn
      omega
    interval_cases n <;> exact ⟨rfl, rfl, by kernel_rfl⟩⟩

/-- **The first shuffle** (`WarpShfl`; `hx2` at 67bd004, its `m2` unfolded): from the threads at
it (`hw2`'s statuses) on the memory they leave, lane `j` resumed from `u2 j` with `r2 j`, lane
`j ^^^ 1`'s thread number; by `m1_eq` on `m1`, each lane's checks by the kernel. A test of
`WarpShfl` at these statuses; `warp` does not give it, since `WarpRun`'s statuses, threads and
deliveries are existential, and getting these back needs the runs in turn to be unique (there is
no `Seq.ToWait.det`) and the deliveries on the lanes to be. -/
theorem hx2 : WarpShfl L c 0
    (fun n => .wait (u2 n) (.shfl .bfly)
      [.bits 32 (-1), .bits 32 (.ofNat 32 n), .bits 32 1, .bits 32 31] shflDecl) (memAt t1 m1 4)
      u2 r2 := by
  rw [m1_eq.1]
  refine ⟨.bfly, fun _ => .bits 32 (-1), fun n => .bits 32 (.ofNat 32 n), fun _ => .bits 32 1,
    fun _ => .bits 32 31, fun _ => 1, fun _ => 31, fun _ => shflDecl, fun j hj => ?_⟩
  have hj : j < 4 := by simpa [show warpLanes L 0 = List.range 4 by decide] using hj
  interval_cases j <;> exact ⟨rfl, rfl, rfl, rfl, by kernel_rfl, by kernel_rfl⟩

/-- **The second shuffle** (`WarpShfl`; `hx3` at 67bd004, its `m2`, `m3` and `u3` unfolded): from
`hw3`'s statuses on the memory the threads leave, lane `j` resumed from
`stop t2 (memAt t1 m1 4) j` with `r3 j`, lane `j ^^^ 2`'s `a3`; by `m1_eq` on `m1`. A test of
`WarpShfl`; `warp` does not give it, as for `hx2`. -/
theorem hx3 : WarpShfl L c 0 (fun n => .wait (stop t2 (memAt t1 m1 4) n) (.shfl .bfly)
      [.bits 32 (-1), a3 n, .bits 32 2, .bits 32 31] shflDecl) (memAt t2 (memAt t1 m1 4) 4)
      (stop t2 (memAt t1 m1 4)) r3 := by
  rw [m1_eq.2.1, m1_eq.1]
  refine ⟨.bfly, fun _ => .bits 32 (-1), a3, fun _ => .bits 32 2, fun _ => .bits 32 31,
    fun _ => 2, fun _ => 31, fun _ => shflDecl, fun j hj => ?_⟩
  have hj : j < 4 := by simpa [show warpLanes L 0 = List.range 4 by decide] using hj
  interval_cases j <;> exact ⟨rfl, rfl, rfl, rfl, by kernel_rfl, by kernel_rfl⟩

/-- The value lane `j` offers at shuffle `i`: its `%0` (its thread number), then `a3 j`. -/
def x (i j : Nat) : Val := if i = 0 then .bits 32 (.ofNat 32 j) else a3 j

/-- Lane `j`'s waits past the barrier, in `kern`'s block 0 on memory `m`: the first shuffle at
position 2 offering `x 0 j`, delivered `r2 j`, and the second at position 4 offering `x 1 j`,
delivered `r3 j`; no lane changes the memory. -/
def ws (m : Mem) (j : Nat) : List Piece.Wait :=
  [⟨2, .shfl .bfly, [.bits 32 (-1), x 0 j, .bits 32 1, .bits 32 31], m, (r2 j, m)⟩,
    ⟨4, .shfl .bfly, [.bits 32 (-1), x 1 j, .bits 32 2, .bits 32 31], m, (r3 j, m)⟩]

/-- The `i`-th of `ws m j` (a barrier wait at position 0 on the empty memory if there is none). -/
def wt (m : Mem) (i j : Nat) : Piece.Wait := (ws m j).getD i ⟨0, .barrier, [], {}, (none, {})⟩

/-- **Each lane past the barrier through its two waits** (`RunsVia` at `Piece.Wait.via` of block
0), as `runTo` computes it: from `t1 j` on `m1` to the first shuffle at `u2 j`, from `t2 j` to the
second at `u3 j`, and from `t3 j` to its return on `m1`. -/
theorem lane : ∀ j < 4, RunsVia (c (0 + j)) (· = m1) ((ws m1 j).map (Piece.Wait.via kern 0))
    (t1 (0 + j)) m1 := by
  intro j hj
  refine ⟨u2 j, _, _, shflDecl, m1, ToWait.of_runTo (fuel := 4) ?_, ⟨?_, rfl, rfl, rfl⟩,
    u3 j, _, _, shflDecl, m1, ToWait.of_runTo (fuel := 4) ?_, ⟨?_, rfl, rfl, rfl⟩,
    m1, Runs.of_runTo (fuel := 4) (u := u4 j) (m₁ := m1) ?_, rfl⟩ <;>
    interval_cases j <;> kernel_rfl

/-- Each lane has two waits and runs the program `prog`. -/
theorem waits : ∀ j < 4, (ws m1 j).length = 2 ∧ (c (0 + j)).prog = prog :=
  fun j hj => ⟨rfl, by interval_cases j <;> rfl⟩

/-- **The lanes' waits are the two butterfly shuffles** (`Piece.Wait.shflOk`): at positions 2 and
4, offsets 1 and 2, clamp 31, lane `j` offering `x i j` and delivered what `Grid.fire` delivers,
by the kernel. -/
theorem shfls : ∀ j < 4, Piece.Wait.shflOk (warpLanes L 0) (fun _ => .bfly)
    (fun i => if i = 0 then 2 else 4) (fun i => if i = 0 then 1 else 2) (fun _ => 31) x
    ⟨0, .barrier, [], {}, (none, {})⟩ 2 j (ws m1 j) = true := by
  decide +kernel

/-- The waits are on `m` and deliver `m`, for every memory `m` and lanes `ls`. -/
theorem mems {m : Mem} {ls : List Nat} :
    ∀ i < 2, ∀ j ∈ ls, (wt m i j).mem = m ∧ (wt m i j).dlv.2 = m :=
  fun i hi _ _ => by interval_cases i <;> exact ⟨rfl, rfl⟩

/-- **The warp past the barrier through the two shuffles** (`WarpRun`), from `t1` on `m1`, by
`warp_route`: `WarpRun.of_waits` with the lanes' runs by `lane` (`RunsVia.of_block`) and the
shuffles by `WarpRun.shfl_of`, from `shfls` and `Program.shfl_nil`; so each shuffle's deliveries
are `Grid.fire`'s (`WarpShfl`). -/
theorem warp : ∃ Es, WarpRun L c 0 t1 m1 Es m1 := by
  have hN : (warpLanes L 0).length = 4 := by decide
  have hl := lane
  have hw := waits
  have hs := shfls
  warp_route (J := 2) (fn := kern) (lbl := fun _ => 0) (W := wt m1) (mo := fun _ => .bfly)
    (X := x) (M := fun _ _ => m1) using mems, Program.shfl_nil (P := prog) (by decide)

/-- **The launch through a barrier and two shuffles is sound** (`Grid.Sound`), with the
observation that is always `()`: by `PhaseRun.start_sound` at the run of the one block
(`BlockRun`): its one warp's run to the barrier (`CanonWait`, `WarpWait.waits`), the barrier
(`hb1`), then the warp's run through the two shuffles to the returns (`warp`); the final trace's
checks by the kernel. -/
theorem sound : Grid.Sound L c g0 (fun _ => some ()) fun _ => True := by
  obtain ⟨_, w1⟩ := hw1
  obtain ⟨_, w⟩ := warp
  rw [← warp0] at w1
  have e1 : CanonWait L c (Grid.thread g0)
      (fun n => .wait (u1 n) .barrier [.bits 32 0] Launch.barrierDecl) [0] g0.mem _ _ :=
    .cons (.waits w1) (.nil _)
  have e2 : CanonRun L c t1 [0] m1 _ m1 := .cons w (.nil _)
  rw [show [0] = blockWarps L 0 by decide] at e1 e2
  have hr : BlockRun L c 0 (Grid.thread g0) g0.mem _ m1 := .bar e1 hb1 (.ends e2)
  have hc : PhaseRun L c (Grid.thread g0) [0] g0.mem _ m1 := .cons hr (.nil _)
  rw [show [0] = List.range (volume L.grid) by decide] at hc
  exact PhaseRun.start_sound start_eq (fun _ _ _ _ _ hc => by cases hc) (fun _ _ _ => rfl)
    (by decide) hc ⟨fun _ _ => by decide +kernel, by decide +kernel, (), rfl, trivial⟩

/-- Register `r` of lane `l` at its return, as a number (0 if it is not an integer). -/
def reg (r l : Nat) : Nat :=
  (((u4 l).frames.head?.bind (·.regs r)).bind Val.word?).getD 0

/-- **The lanes hold the butterfly rounds of their thread numbers**: at its return, each lane
`l < 4` holds in `%4` the value `bflyRounds (· + ·) [1, 2] (fun l => l) l` of the rounds at
offsets 1 and 2 over the lanes' `%0`, by `bflyRoundsAt_of_shfl` at round `r`'s register `%(2r)`
and one combination, `add`, in every round and lane: each round's `add` combines the lane's value
with that of the lane `shflSource` gives. -/
theorem lanes : ∀ l < 4, reg 4 l = bflyRounds (· + ·) [1, 2] (fun l => l) l :=
  bflyRoundsAt_of_shfl (k := 2) (by decide) (ms := [1, 2]) (by decide)
    (F := fun _ _ => (· + ·)) (v := fun r l => reg (2 * r) l)
    (fun l hl => by interval_cases l <;> kernel_rfl)
    fun r hr l hl => by
      simp only [List.length_cons, List.length_nil] at hr
      interval_cases r <;> interval_cases l <;> kernel_rfl

/-- **The rounds' value**: the butterfly rounds at offsets 1 and 2 over the thread numbers give
every lane `l < 4` the sum `0 + 1 + 2 + 3 = 6`, by evaluation. -/
theorem lanes_six : ∀ l < 4, bflyRounds (· + ·) [1, 2] (fun l => l) l = 6 := by
  decide

/--
error: unsolved goals
case refine_2
⊢ ∀ i < 2,
    ∀ j ∈ warpLanes L 0,
      (wt m1 i j).call.intr = Intrinsic.shfl Shfl.bfly ∧
        (wt m1 i j).pos = (wt m1 i 0).pos ∧
          ∃ Mk Bv Cv b cl,
            (wt m1 i j).args = [Mk, x i j, Bv, Cv] ∧
              Mk.word? = some (2 ^ 32 - 1) ∧
                Bv.word? = some b ∧
                  Cv.word? = some cl ∧
                    ∀ (g : String) (e : Func),
                      Array.find? (fun x => x.name == g) (c (0 + j)).prog.module.funcs = some e →
                        List.lookup g (c (0 + j)).prog.intrinsics = some (Intrinsic.shfl Shfl.bfly) →
                          Option.mapM (withAttrs (c 0).prog.layout m1 e.ret e.retAttrs)
                              (some (shflVal (warpLanes L 0) (x i) (shflSource Shfl.bfly j b cl))) =
                            Except.ok (wt m1 i j).dlv.1
-/
#guard_msgs in
/-- **The open-goal twin**: the warp's run past the barrier without the shuffles' checks
(`shfls`) leaves `WarpRun.of_waits`' premise on the shuffles (`hW`) as the goal. -/
example : ∃ Es, WarpRun L c 0 t1 m1 Es m1 := by
  have hN : (warpLanes L 0).length = 4 := by decide
  have hl := lane
  have hw := waits
  warp_route (J := 2) (fn := kern) (lbl := fun _ => 0) (W := wt m1) (mo := fun _ => .bfly)
    (X := x) (M := fun _ _ => m1) using mems, Program.shfl_nil (P := prog) (by decide)
  clear * -

end MojoProofTest.SymColl
