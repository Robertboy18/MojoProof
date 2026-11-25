import MojoProofTest.Confluence
import MojoProof.Sym.SchedWait
import MojoProofTest.KernelRfl

/-!
# A schedule of a barrier and two butterfly shuffles, on a concrete launch

Instances of `Sched.start_sound`, `Fires.barriers`, `Fires.shfls`, `Seq.ToWait.of_runTo`,
`Seq.of_runTo` and `bflyRoundsAt_of_shfl` (MojoProof/Sym/SchedWait.lean). The kernel `kern` is

    %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
    call void @llvm.nvvm.barrier.cta.sync.aligned.all(i32 0)
    %1 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %0, i32 1, i32 31)
    %2 = add i32 %0, %1
    %3 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %2, i32 2, i32 31)
    %4 = add i32 %2, %3
    ret void

with the barrier and the shuffle declared `convergent`, launched on one block of four threads
(`launch2 1 1 4 1`) on the empty memory, with address choice and oracle 0.

* `sound`: the launch is sound (`Grid.Sound`), by `Sched.start_sound` at a schedule of three
  phases and the ends: the threads in turn to the barrier and the barrier (`Fires.barriers`); the
  threads in turn to the first shuffle and the shuffle (`Fires.shfls`, each lane resumed with
  `shflSource`'s lane's `%0`); the same for the second shuffle with `%2`; the threads in turn to
  their returns. Each phase's runs are the ones `runTo` computes (`Seq.ToWait.of_runTo`,
  `Seq.of_runTo`).
* `lanes`: at its return each lane `l` holds in `%4` the value of the butterfly rounds at offsets
  1 and 2 over the lanes' thread numbers (`bflyRounds (· + ·) [1, 2] (fun l => l) l`, by
  `bflyRoundsAt_of_shfl`), which is 6 (`lanes_six`).
* The open-goal twin (an `example` with `#guard_msgs`): the schedule with the second shuffle's
  fire left out leaves that phase's `Fires` as the goal.

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

/-- The memory at the first shuffle. -/
def m2 : Mem := memAt t1 m1 4

/-- Lane `n`'s `%1`, what the first shuffle gives it: lane `n ^^^ 1`'s `%0`. -/
def r2 (n : Nat) : Option Val := some (.bits 32 (BitVec.ofNat 32 (n ^^^ 1)))

/-- The threads past the first shuffle. -/
def t2 (n : Nat) : Thread := (u2 n).resume (r2 n)

/-- The threads at the second shuffle. -/
def u3 : Nat → Thread := stop t2 m2

/-- The memory at the second shuffle. -/
def m3 : Mem := memAt t2 m2 4

/-- Lane `n`'s `%2`, the value it offers at the second shuffle. -/
def a3 (n : Nat) : Val := .bits 32 (BitVec.ofNat 32 (n + (n ^^^ 1)))

/-- Lane `n`'s `%3`, what the second shuffle gives it: lane `n ^^^ 2`'s `%2`. -/
def r3 (n : Nat) : Option Val := some (.bits 32 (BitVec.ofNat 32 ((n ^^^ 2) + (n ^^^ 2 ^^^ 1))))

/-- The threads past the second shuffle. -/
def t3 (n : Nat) : Thread := (u3 n).resume (r3 n)

/-- The memory the threads end on. -/
def fin : Mem := memAt t3 m3 4

/-- The threads at their returns. -/
def u4 : Nat → Thread := stop t3 m3

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

/-- The threads in turn to the first shuffle, each lane `n` offering its `%0`, its thread
number. -/
theorem hw2 : ∃ Es, Seq.ToWait c t1
    (fun n => .wait (u2 n) (.shfl .bfly)
      [.bits 32 (-1), .bits 32 (.ofNat 32 n), .bits 32 1, .bits 32 31] shflDecl)
    (List.range 4) m1 Es m2 := by
  obtain ⟨Es, h⟩ := Seq.ToWait.of_runTo (c := c) (t := t1) (N := 4) (fuel := 4)
    (s := fun n => .wait (u2 n) (.shfl .bfly)
      [.bits 32 (-1), .bits 32 (.ofNat 32 n), .bits 32 1, .bits 32 31] shflDecl)
    (mem := memAt t1 m1) fun k hk => by
      refine ⟨_, _, _, _, rfl, ?_⟩
      interval_cases k <;> kernel_rfl
  rw [memAt.eq_1] at h
  exact ⟨Es, h⟩

/-- The threads in turn to the second shuffle. -/
theorem hw3 : ∃ Es, Seq.ToWait c t2
    (fun n => .wait (u3 n) (.shfl .bfly) [.bits 32 (-1), a3 n, .bits 32 2, .bits 32 31] shflDecl)
    (List.range 4) m2 Es m3 := by
  obtain ⟨Es, h⟩ := Seq.ToWait.of_runTo (c := c) (t := t2) (N := 4) (fuel := 4)
    (s := fun n => .wait (u3 n) (.shfl .bfly) [.bits 32 (-1), a3 n, .bits 32 2, .bits 32 31]
      shflDecl) (mem := memAt t2 m2) fun k hk => by
      refine ⟨_, _, _, _, rfl, ?_⟩
      interval_cases k <;> kernel_rfl
  rw [memAt.eq_1] at h
  exact ⟨Es, h⟩

/-- The threads in turn to their returns. -/
theorem hs4 : ∃ Es, Seq c t3 (List.range 4) m3 Es fin := by
  obtain ⟨Es, h⟩ := Seq.of_runTo (c := c) (t := t3) (N := 4) (fuel := 4) (mem := memAt t3 m3)
    fun k hk => by
      refine ⟨(next k (t3 k) (memAt t3 m3 k)).1, (next k (t3 k) (memAt t3 m3 k)).2.1, ?_⟩
      interval_cases k <;> kernel_rfl
  rw [memAt.eq_1] at h
  exact ⟨Es, h⟩

/-- The barrier, from the threads at it to `t1` on `m1`. -/
theorem hf1 : Fires L c 4 (fun n => .wait (u1 n) .barrier [.bits 32 0] Launch.barrierDecl)
    (memAt (Grid.thread g0) g0.mem 4) t1 m1 :=
  Fires.barriers (B := 1) (bar := fun _ => 0) (by decide) rfl fun n hn => by
    interval_cases n <;> exact ⟨rfl, by decide, by kernel_rfl⟩

/-- The first shuffle, from the threads at it on `m2` to `t2`. -/
theorem hf2 : Fires L c 4
    (fun n => .wait (u2 n) (.shfl .bfly)
      [.bits 32 (-1), .bits 32 (.ofNat 32 n), .bits 32 1, .bits 32 31] shflDecl)
    m2 t2 m2 :=
  Fires.shfls (B := 1) (b := fun _ => 1) (cl := fun _ => 31) (by decide) rfl fun n hn => by
    interval_cases n <;> exact ⟨rfl, rfl, rfl, by kernel_rfl, by kernel_rfl⟩

/-- The second shuffle, from the threads at it on `m3` to `t3`. -/
theorem hf3 : Fires L c 4
    (fun n => .wait (u3 n) (.shfl .bfly) [.bits 32 (-1), a3 n, .bits 32 2, .bits 32 31] shflDecl)
    m3 t3 m3 :=
  Fires.shfls (B := 1) (b := fun _ => 2) (cl := fun _ => 31) (by decide) rfl fun n hn => by
    interval_cases n <;> exact ⟨rfl, rfl, rfl, by kernel_rfl, by kernel_rfl⟩

/-- **The launch through a barrier and two shuffles is sound** (`Grid.Sound`), with the
observation that is always `()`: by `Sched.start_sound` at the schedule of the three phases and
the ends, with the runs `runTo` computes; the final trace's checks by the kernel. -/
theorem sound : Grid.Sound L c g0 (fun _ => some ()) fun _ => True := by
  have hsz : g0.threads.size = 4 := rfl
  obtain ⟨_, w1⟩ := hw1
  obtain ⟨_, w2⟩ := hw2
  obtain ⟨_, w3⟩ := hw3
  obtain ⟨_, s4⟩ := hs4
  have hS : Sched L c 4 (Grid.thread g0) g0.mem fin :=
    .wait w1 hf1 (.wait w2 hf2 (.wait w3 hf3 (.ends s4)))
  rw [← hsz] at hS
  exact Sched.start_sound start_eq (fun _ _ _ _ _ hc => by cases hc) (fun _ _ _ => rfl) hS
    (fun _ _ => by decide +kernel) (by decide +kernel) rfl trivial

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
⊢ Fires L c 4
    (fun n =>
      Status.wait (u3 n) (Intrinsic.shfl Shfl.bfly) [Val.bits 32 (-1), a3 n, Val.bits 32 2, Val.bits 32 31] shflDecl)
    m3 t3 m3
-/
#guard_msgs in
/-- **The open-goal twin**: the schedule with the second shuffle's fire left out leaves that
phase's `Fires` (the second shuffle from the threads at it to `t3`) as the goal. -/
example : Sched L c 4 (Grid.thread g0) g0.mem fin := by
  obtain ⟨_, w1⟩ := hw1
  obtain ⟨_, w2⟩ := hw2
  obtain ⟨_, w3⟩ := hw3
  obtain ⟨_, s4⟩ := hs4
  refine .wait w1 hf1 (.wait w2 hf2 (.wait w3 ?_ (.ends s4)))
  clear * -

end MojoProofTest.SymColl
