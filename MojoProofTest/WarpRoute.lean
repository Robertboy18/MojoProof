import MojoProof.Sym.WarpRoute

/-!
# `warp_route` on goals of a warp's run

`warp_route` (MojoProof/Sym/WarpRoute.lean) at every launch, contexts, warp, threads and memory,
with every wait at one memory `m` (`M := fun _ _ => m`):

* no phase (`J := 0`), the lanes' runs `Runs` to `m`, `∀ j < N` with
  `(warpLanes L k).length = N`: the hypothesis is lifted to `∀ j ∈ warpLanes L k` and the lanes'
  runs close by `RunsVia.of_runs`; with the term of the lanes' runs after `using`, too; with runs
  to memories `f j` of which no fact says that they are `m`, the lanes' runs stay the one goal;
* one phase (`J := 1`), the lanes' runs through `(ws j).map (Piece.Wait.via fn 3)`, a program `P`
  every lane's context runs, the waits' `Piece.Wait.shflOk` and memories, and `P.shflNil`: no
  goal stays (`RunsVia.of_block`, `WarpRun.shfl_of`, `MojoProof.LLVM.Program.shfl_nil`); without
  the waits' lengths, the lanes' runs stay the one goal; without `P.shflNil`, `WarpRun.shfl_of`'s
  keeping premise stays the one goal;
* two phases (`J := 2`), the lanes' runs through `(a j).map (Piece.Wait.via fn 3) ++
  (b j).map (Piece.Wait.via fn 4)`: no goal stays with the labels `3` below 1 and `4` from 1
  (`RunsVia.of_blocks`); with the label `3` at both, the lanes' runs stay the one goal;
* two phases, the lanes' runs through a list literal and the waits' memories
  `∀ j < (warpLanes L k).length`: the lanes' runs by the lifted hypothesis, the waits' memories
  phase by phase by its conjuncts at the lane, the phases' starts by `rfl`; the shuffles, of which
  no hypothesis speaks, stay the one goal, as `WarpRun.of_waits` states them;
* a goal that is not a warp's run: refused, with a message.

The kernels' uses are `warp78` and `warp43` (MojoProofTest/GemvWarp.lean), `skipWarp` and
`shflWarp` (MojoProofTest/SymCanon.lean).
-/

namespace MojoProofTest.WarpRoute

open MojoProof MojoProof.Sem MojoProof.Sym

example {L : Launch} {c : Nat → Ctx} {k N : Nat} {t : Nat → Thread} {m : Mem} (w : Piece.Wait)
    (fn : LLVM.Func) (hN : (warpLanes L k).length = N)
    (h : ∀ j < N, Runs (c (k + j)) (t (k + j)) m m) :
    ∃ Es, WarpRun L c k t m Es m := by
  warp_route (J := 0) (fn := fn) (lbl := fun _ => 0) (W := fun _ _ => w) (mo := fun _ => .bfly)
    (X := fun _ _ => .poison) (M := fun _ _ => m)

/--
error: unsolved goals
case refine_1
L : Launch
c : ℕ → Ctx
k N : ℕ
t : ℕ → Thread
m : Mem
w : Piece.Wait
fn : LLVM.Func
f : ℕ → Mem
hN : (warpLanes L k).length = N
h : ∀ j ∈ warpLanes L k, Runs (c (k + j)) (t (k + j)) m (f j)
⊢ ∀ j ∈ warpLanes L k,
    RunsVia (c (k + j)) (fun x => x = m) (List.map (fun i => Piece.Wait.via fn 0 w) (List.range 0)) (t (k + j)) m
-/
#guard_msgs in
example {L : Launch} {c : Nat → Ctx} {k N : Nat} {t : Nat → Thread} {m : Mem} (w : Piece.Wait)
    (fn : LLVM.Func) (f : Nat → Mem) (hN : (warpLanes L k).length = N)
    (h : ∀ j < N, Runs (c (k + j)) (t (k + j)) m (f j)) :
    ∃ Es, WarpRun L c k t m Es m := by
  warp_route (J := 0) (fn := fn) (lbl := fun _ => 0) (W := fun _ _ => w) (mo := fun _ => .bfly)
    (X := fun _ _ => .poison) (M := fun _ _ => m)

example {L : Launch} {c : Nat → Ctx} {k N : Nat} {t : Nat → Thread} {m : Mem} (w : Piece.Wait)
    (fn : LLVM.Func) (hN : (warpLanes L k).length = N)
    (h : ∀ j < N, Runs (c (k + j)) (t (k + j)) m m) :
    ∃ Es, WarpRun L c k t m Es m := by
  warp_route (J := 0) (fn := fn) (lbl := fun _ => 0) (W := fun _ _ => w) (mo := fun _ => .bfly)
    (X := fun _ _ => .poison) (M := fun _ _ => m) using fun j hj => ⟨_, h j hj, rfl⟩

example {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m : Mem} {P : LLVM.Program}
    {fn : LLVM.Func} {d : Piece.Wait} {ws : Nat → List Piece.Wait} {X : Nat → Nat → Val}
    (hr : ∀ j < (warpLanes L k).length,
      RunsVia (c (k + j)) (· = m) ((ws j).map (Piece.Wait.via fn 3)) (t (k + j)) m)
    (hP : ∀ j < (warpLanes L k).length, (c (k + j)).prog = P)
    (hs : ∀ j < (warpLanes L k).length, Piece.Wait.shflOk (warpLanes L k) (fun _ => .bfly)
      (fun _ => 0) (fun _ => 16) (fun _ => 31) X d 1 j (ws j) = true)
    (hm : ∀ j < (warpLanes L k).length, ((ws j).getD 0 d).mem = m ∧ ((ws j).getD 0 d).dlv.2 = m)
    (hl : ∀ j < (warpLanes L k).length, (ws j).length = 1) (hN : P.shflNil = true) :
    ∃ Es, WarpRun L c k t m Es m := by
  warp_route (J := 1) (fn := fn) (lbl := fun _ => 3) (W := fun i j => (ws j).getD i d)
    (mo := fun _ => .bfly) (X := X) (M := fun _ _ => m)

/--
error: unsolved goals
case refine_1
L : Launch
c : ℕ → Ctx
k : ℕ
t : ℕ → Thread
m : Mem
P : LLVM.Program
fn : LLVM.Func
d : Piece.Wait
ws : ℕ → List Piece.Wait
X : ℕ → ℕ → Val
hN : P.shflNil = true
hr : ∀ j ∈ warpLanes L k, RunsVia (c (k + j)) (fun x => x = m) (List.map (Piece.Wait.via fn 3) (ws j)) (t (k + j)) m
hP : ∀ j ∈ warpLanes L k, (c (k + j)).prog = P
hs :
  ∀ j ∈ warpLanes L k,
    Piece.Wait.shflOk (warpLanes L k) (fun x => LLVM.Shfl.bfly) (fun x => 0) (fun x => 16) (fun x => 31) X d 1 j
        (ws j) =
      true
hm : ∀ j ∈ warpLanes L k, ((ws j).getD 0 d).mem = m ∧ ((ws j).getD 0 d).dlv.2 = m
⊢ ∀ j ∈ warpLanes L k,
    RunsVia (c (k + j)) (fun x => x = m) (List.map (fun i => Piece.Wait.via fn 3 ((ws j).getD i d)) (List.range 1))
      (t (k + j)) m
-/
#guard_msgs in
example {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m : Mem} {P : LLVM.Program}
    {fn : LLVM.Func} {d : Piece.Wait} {ws : Nat → List Piece.Wait} {X : Nat → Nat → Val}
    (hr : ∀ j < (warpLanes L k).length,
      RunsVia (c (k + j)) (· = m) ((ws j).map (Piece.Wait.via fn 3)) (t (k + j)) m)
    (hP : ∀ j < (warpLanes L k).length, (c (k + j)).prog = P)
    (hs : ∀ j < (warpLanes L k).length, Piece.Wait.shflOk (warpLanes L k) (fun _ => .bfly)
      (fun _ => 0) (fun _ => 16) (fun _ => 31) X d 1 j (ws j) = true)
    (hm : ∀ j < (warpLanes L k).length, ((ws j).getD 0 d).mem = m ∧ ((ws j).getD 0 d).dlv.2 = m)
    (hN : P.shflNil = true) :
    ∃ Es, WarpRun L c k t m Es m := by
  warp_route (J := 1) (fn := fn) (lbl := fun _ => 3) (W := fun i j => (ws j).getD i d)
    (mo := fun _ => .bfly) (X := X) (M := fun _ _ => m)

/--
error: unsolved goals
case refine_2.hK
L : Launch
c : ℕ → Ctx
k : ℕ
t : ℕ → Thread
m : Mem
P : LLVM.Program
fn : LLVM.Func
d : Piece.Wait
ws : ℕ → List Piece.Wait
X : ℕ → ℕ → Val
hr : ∀ j ∈ warpLanes L k, RunsVia (c (k + j)) (fun x => x = m) (List.map (Piece.Wait.via fn 3) (ws j)) (t (k + j)) m
hP : ∀ j ∈ warpLanes L k, (c (k + j)).prog = P
hs :
  ∀ j ∈ warpLanes L k,
    Piece.Wait.shflOk (warpLanes L k) (fun x => LLVM.Shfl.bfly) (fun x => 0) (fun x => 16) (fun x => 31) X d 1 j
        (ws j) =
      true
hm : ∀ j ∈ warpLanes L k, ((ws j).getD 0 d).mem = m ∧ ((ws j).getD 0 d).dlv.2 = m
hl : ∀ j ∈ warpLanes L k, (ws j).length = 1
⊢ ∀ i < 1,
    ∀ j ∈ warpLanes L k,
      ∀ (g : String) (e : LLVM.Func),
        Array.find? (fun x => x.name == g) P.module.funcs = some e →
          List.lookup g P.intrinsics = some (LLVM.Intrinsic.shfl LLVM.Shfl.bfly) →
            Option.mapM (withAttrs P.layout m e.ret e.retAttrs)
                (some
                  (shflVal (warpLanes L k) (X i) (shflSource LLVM.Shfl.bfly j (BitVec.toNat 16) (BitVec.toNat 31)))) =
              Except.ok
                (some (shflVal (warpLanes L k) (X i) (shflSource LLVM.Shfl.bfly j (BitVec.toNat 16) (BitVec.toNat 31))))
-/
#guard_msgs in
example {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m : Mem} {P : LLVM.Program}
    {fn : LLVM.Func} {d : Piece.Wait} {ws : Nat → List Piece.Wait} {X : Nat → Nat → Val}
    (hr : ∀ j < (warpLanes L k).length,
      RunsVia (c (k + j)) (· = m) ((ws j).map (Piece.Wait.via fn 3)) (t (k + j)) m)
    (hP : ∀ j < (warpLanes L k).length, (c (k + j)).prog = P)
    (hs : ∀ j < (warpLanes L k).length, Piece.Wait.shflOk (warpLanes L k) (fun _ => .bfly)
      (fun _ => 0) (fun _ => 16) (fun _ => 31) X d 1 j (ws j) = true)
    (hm : ∀ j < (warpLanes L k).length, ((ws j).getD 0 d).mem = m ∧ ((ws j).getD 0 d).dlv.2 = m)
    (hl : ∀ j < (warpLanes L k).length, (ws j).length = 1) :
    ∃ Es, WarpRun L c k t m Es m := by
  warp_route (J := 1) (fn := fn) (lbl := fun _ => 3) (W := fun i j => (ws j).getD i d)
    (mo := fun _ => .bfly) (X := X) (M := fun _ _ => m)

example {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m : Mem} {P : LLVM.Program}
    {fn : LLVM.Func} {d : Piece.Wait} {a b : Nat → List Piece.Wait} {X : Nat → Nat → Val}
    (hr : ∀ j < (warpLanes L k).length, RunsVia (c (k + j)) (· = m)
      ((a j).map (Piece.Wait.via fn 3) ++ (b j).map (Piece.Wait.via fn 4)) (t (k + j)) m)
    (ha : ∀ j < (warpLanes L k).length, (a j).length = 1 ∧ (a j ++ b j).length = 2)
    (hP : ∀ j < (warpLanes L k).length, (c (k + j)).prog = P) (hN : P.shflNil = true)
    (hs : ∀ j < (warpLanes L k).length, Piece.Wait.shflOk (warpLanes L k) (fun _ => .bfly)
      (fun _ => 0) (fun _ => 16) (fun _ => 31) X d 2 j (a j ++ b j) = true)
    (hm : ∀ j < (warpLanes L k).length, ∀ i < 2,
      ((a j ++ b j).getD i d).mem = m ∧ ((a j ++ b j).getD i d).dlv.2 = m) :
    ∃ Es, WarpRun L c k t m Es m := by
  warp_route (J := 2) (fn := fn) (lbl := fun i => if i < 1 then 3 else 4)
    (W := fun i j => (a j ++ b j).getD i d) (mo := fun _ => .bfly) (X := X) (M := fun _ _ => m)

/--
error: unsolved goals
case refine_1
L : Launch
c : ℕ → Ctx
k : ℕ
t : ℕ → Thread
m : Mem
P : LLVM.Program
fn : LLVM.Func
d : Piece.Wait
a b : ℕ → List Piece.Wait
X : ℕ → ℕ → Val
hN : P.shflNil = true
hr :
  ∀ j ∈ warpLanes L k,
    RunsVia (c (k + j)) (fun x => x = m) (List.map (Piece.Wait.via fn 3) (a j) ++ List.map (Piece.Wait.via fn 4) (b j))
      (t (k + j)) m
ha : ∀ j ∈ warpLanes L k, (a j).length = 1 ∧ (a j ++ b j).length = 2
hP : ∀ j ∈ warpLanes L k, (c (k + j)).prog = P
hs :
  ∀ j ∈ warpLanes L k,
    Piece.Wait.shflOk (warpLanes L k) (fun x => LLVM.Shfl.bfly) (fun x => 0) (fun x => 16) (fun x => 31) X d 2 j
        (a j ++ b j) =
      true
hm : ∀ j ∈ warpLanes L k, ∀ i < 2, ((a j ++ b j).getD i d).mem = m ∧ ((a j ++ b j).getD i d).dlv.2 = m
⊢ ∀ j ∈ warpLanes L k,
    RunsVia (c (k + j)) (fun x => x = m)
      (List.map (fun i => Piece.Wait.via fn 3 ((a j ++ b j).getD i d)) (List.range 2)) (t (k + j)) m
-/
#guard_msgs in
example {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m : Mem} {P : LLVM.Program}
    {fn : LLVM.Func} {d : Piece.Wait} {a b : Nat → List Piece.Wait} {X : Nat → Nat → Val}
    (hr : ∀ j < (warpLanes L k).length, RunsVia (c (k + j)) (· = m)
      ((a j).map (Piece.Wait.via fn 3) ++ (b j).map (Piece.Wait.via fn 4)) (t (k + j)) m)
    (ha : ∀ j < (warpLanes L k).length, (a j).length = 1 ∧ (a j ++ b j).length = 2)
    (hP : ∀ j < (warpLanes L k).length, (c (k + j)).prog = P) (hN : P.shflNil = true)
    (hs : ∀ j < (warpLanes L k).length, Piece.Wait.shflOk (warpLanes L k) (fun _ => .bfly)
      (fun _ => 0) (fun _ => 16) (fun _ => 31) X d 2 j (a j ++ b j) = true)
    (hm : ∀ j < (warpLanes L k).length, ∀ i < 2,
      ((a j ++ b j).getD i d).mem = m ∧ ((a j ++ b j).getD i d).dlv.2 = m) :
    ∃ Es, WarpRun L c k t m Es m := by
  warp_route (J := 2) (fn := fn) (lbl := fun _ => 3)
    (W := fun i j => (a j ++ b j).getD i d) (mo := fun _ => .bfly) (X := X) (M := fun _ _ => m)

/--
error: unsolved goals
case refine_2
L : Launch
c : ℕ → Ctx
k : ℕ
t : ℕ → Thread
m : Mem
W : ℕ → ℕ → Piece.Wait
fn : LLVM.Func
hr :
  ∀ j ∈ warpLanes L k,
    RunsVia (c (k + j)) (fun x => x = m) [Piece.Wait.via fn 3 (W 0 j), Piece.Wait.via fn 3 (W 1 j)] (t (k + j)) m
hm : ∀ j ∈ warpLanes L k, (W 0 j).mem = m ∧ (W 0 j).dlv.2 = m ∧ (W 1 j).mem = m ∧ (W 1 j).dlv.2 = m
⊢ ∀ i < 2,
    ∀ j ∈ warpLanes L k,
      (W i j).call.intr = LLVM.Intrinsic.shfl LLVM.Shfl.bfly ∧
        (W i j).pos = (W i 0).pos ∧
          ∃ Mk Bv Cv b cl,
            (W i j).args = [Mk, Val.poison, Bv, Cv] ∧
              Mk.word? = some (2 ^ 32 - 1) ∧
                Bv.word? = some b ∧
                  Cv.word? = some cl ∧
                    ∀ (g : String) (e : LLVM.Func),
                      Array.find? (fun x => x.name == g) (c (k + j)).prog.module.funcs = some e →
                        List.lookup g (c (k + j)).prog.intrinsics = some (LLVM.Intrinsic.shfl LLVM.Shfl.bfly) →
                          Option.mapM (withAttrs (c k).prog.layout m e.ret e.retAttrs)
                              (some
                                (shflVal (warpLanes L k) (fun x => Val.poison) (shflSource LLVM.Shfl.bfly j b cl))) =
                            Except.ok (W i j).dlv.1
-/
#guard_msgs in
example {L : Launch} {c : Nat → Ctx} {k : Nat} {t : Nat → Thread} {m : Mem}
    (W : Nat → Nat → Piece.Wait) (fn : LLVM.Func)
    (hr : ∀ j < (warpLanes L k).length, RunsVia (c (k + j)) (· = m)
      [(W 0 j).via fn 3, (W 1 j).via fn 3] (t (k + j)) m)
    (hm : ∀ j < (warpLanes L k).length, (W 0 j).mem = m ∧ (W 0 j).dlv.2 = m ∧ (W 1 j).mem = m ∧
      (W 1 j).dlv.2 = m) :
    ∃ Es, WarpRun L c k t m Es m := by
  warp_route (J := 2) (fn := fn) (lbl := fun _ => 3) (W := W) (mo := fun _ => .bfly)
    (X := fun _ _ => .poison) (M := fun _ _ => m)

/-- error: warp_route: the goal is not `∃ Es, WarpRun L c k t m Es m'` -/
#guard_msgs in
example (n : Nat) : n = n := by
  warp_route

end MojoProofTest.WarpRoute
