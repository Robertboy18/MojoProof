import MojoProofTest.SymLane
import MojoProofTest.SymLoop
import MojoProofTest.SymSeg
import MojoProof.Sym.OblSeg

/-!
# gemv_kernel from its entry block to `ret`: the `%43` branch, the loop at `%54` and `%78`

gemv_kernel's entry block `%6` (fixture `gemv`, MojoProofTest/SymLane.lean) starts with three
`alloca`s and calls two shuffles (statements 17 and 18) and lifetime markers (statements 19 to
40). The block checker refuses the block from statement 0 even with the `alloca` flag
(`gemv_allocas_twin`, MojoProofTest/SymAlloca.lean); the segment checker runs it to its branch
(`gemv_segs_alloca`, MojoProofTest/SymSeg.lean). Here the path checker with the flag on
(`coversPathAt true`) takes the block from statement 41, after its last marker, through the
branch to `%43`, the branch taken when the row `%36` is at least the row count `%10`, and `%43`'s
`br` to `%103`, `ret void`. The parser numbers locals by first appearance, so `%103` is local 45
(its first use is `%43`'s `br`); `%6` and `%43` are locals 6 and 43.

* `tail_covers`: the path checker with the flag accepts the path from statement 41 and refuses it
  from statement 40 (the `lifetime.end` of `%9`). None of the path's blocks has an `alloca`, so
  the checker without the flag (`coversPathWith`) accepts it too. The last block's exit is `ret`.
* `tail_ret`: one context (`ctxG`, `ctx0` with gemv_kernel's program and one block of one
  thread), the frame `frameG 0` at statement 41 of `%6`, and the memory `mem0`
  (MojoProofTest/SymRun.lean). Under them the path's premises hold and the path returns
  (`RetWith false`); the kernel evaluates both. `tail_mutant`: with the row
  count 1 (`frameG 1`), the branch goes to `%44`, and the premises fail.
* `tail_runs`: the thread whose one frame is `frameG 0` runs to its end on `mem0`
  (`Runs.of_retAt` with the flag on).

* `gemv_runs`: from statement 0 of `%6` (`frameS 0`, the row count 0, on `mem0`), with the two
  shuffles delivering the row's halves 0 on the memory at the first one (`memW`, `mem0` with the
  three `alloca` blocks), the thread runs through the three `alloca`s, the shuffles at 17 and 18
  and the nine lifetime markers to statement 41 (`Piece.throughTo`, `gP` the segments), and from
  there to `ret` on the `%43` branch (`Runs.of_retAt` with the flag on); `RunsVia.of_fires`
  joins them, and the kernel decides the segments' premises and the path's (`Piece.fires`,
  `retB`). `gemv_runs_mutant`: with the row count 1 the check fails at statement 41 (the branch
  goes to `%44`), and with the shuffles delivering `mem0` it fails at the first lifetime marker,
  whose pointer is into no block of the thread.

## The loop at `%54`

The other branch of `%6` goes to `%44` (local 44), which computes the trip bound `%53` and
branches to the loop's header `%54` (local 55; rounds start at position 2, after its two `phi`s).
A round runs `%58` and `%60`. Block `%60` branches on `%65 < %11` to `%70` (two loads, an
`fmul contract` and an `fadd contract`) or to `%75`. Both arms join at `%76` (from position 1,
after its `phi`), which branches back to `%54`. The path out is `%59 → %78 → %100 → %102 → %103`,
and `%78` (from position 1) calls five `shfl.sync.bfly`s. The locals: `%58` 62, `%59` 63, `%60`
64, `%70` 74, `%75` 75, `%76` 57, `%78` 65, `%100` 101 and `%102` 103.

* `loop_rounds`: with both flags, the loop checker (`LoopSeg.coversRoundAt true true`) accepts a
  round through either arm (`loopA` through `%70`, `loopB` through `%75`). A round's path is
  fixed. The arm it takes is a premise of the round's run (`%60`'s `Exit.dest`), not an
  obligation the checker adds. Without the `contract` flag the checker refuses the `%70` round.
* `loop_refused`: the chain checker (`coversChainAt true true`, from statement 41 of `%6` through
  `%44`) refuses the loop through either arm and the two-loop chain `twoArms`, each with the path
  out above. The block checker has no summary of `%78` from position 1, because its shuffles are
  collectives (segments, MojoProof/Sym/Segment.lean).
* `loop_arms`: with the path out cut after `%59` (its `br` to `%78`, `cut`), the chain checker
  accepts the loop through either arm, and `twoArms` with its last path out cut. That is the chain
  of two loops at the same header: first the `%70` rounds, then one `%75` round as the first
  loop's path out, then the other `%75` rounds. This is the order gemv's rounds take:
  `%65 = %55 * 32 + %40` grows by 32 each round, so `%65 < %11` holds for the first rounds and
  fails for the rest.

## `%78`'s butterfly

* `bfly_covers`: the segment checker summarizes `%78` from position 1 at its five
  `shfl.sync.bfly`s (`bP`, five collective segments), and the path checker with both flags
  accepts the path after the last one, from statement 19 through `%100`'s `store` to `ret`
  (`bflyOut`).
* `bfly_at`: for every thread at statement 41 of `%6` whose entry valuation passes `%6`'s edge
  through `%44` into the loop at `%54` and, with no round, the path out `%59`'s edge into `%78` at
  position 1 (`chainB`), with the five shuffles delivering the `i32` 0 on a memory `m` (`dsB m`),
  the thread runs through the five waits to its end. The chain stops after `%59`'s edge
  (`RunsVia.of_chain`); the segments run through the shuffles (`RunsVia.of_fires`), and the path
  from statement 19 to `ret` (`Runs.of_retAt`). `bfly_runs` is its instance at `frameG 1` (the
  row count 1, `%11 = 0`) on `mem0`.
* `gemv_loop_runs`: from statement 0 of `%6` (`frameS 1`, the row count 1 and `K = 0`, on
  `mem0`), with `%6`'s shuffles delivering `dsG` and `%78`'s `dsB memW`, the thread runs through
  the seven waits to its end: `%6`'s segments, then `bfly_at`, joined by `RunsVia.of_fires`. The
  deliveries are premises, their memories too: `memW` is the memory at `%6`'s first shuffle, not
  the one the thread has at `%78`'s, and which values the warp's other lanes deliver is the
  schedule's, not this thread's. `bfly_mutant`: with the row count 0 the chain's edge into the
  loop fails, from statement 41 and from statement 0, and with four deliveries the segments'
  check fails.
-/

namespace MojoProofTest.SymGemvTail

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.SymRun MojoProofTest.SymLoop MojoProofTest.SymSeg

/-- The summary of gemv_kernel's block `l` from position `p` with the `alloca` flag
(`summarizeAt true`, the exit from `SState.exitAt`), the default summary when there is none. -/
def gS (l p : Nat) : Summary :=
  (summarizeAt true gemv.prog gemv.fn_0 l p fun σ tm => σ.exitAt gemv.fn_0 l tm).getD default

/-- The path `%6` (from statement 41) `→ %43 → %103` (locals 6, 43 and 45), each block with its
summary's own obligations. -/
def tailPs : List (Nat × List Cond × Summary) :=
  [(6, (gS 6 41).obls, gS 6 41), (43, (gS 43 0).obls, gS 43 0), (45, (gS 45 0).obls, gS 45 0)]

/-- **The path checker with the flag accepts the tail of `%6` and the branch to `ret`**
(`coversPathAt true`, from statement 41). It refuses the same path from statement 40, the
`lifetime.end` of `%9`. The checker without the flag (`coversPathWith`) accepts the path too,
because none of its blocks has an `alloca`. The exit of `%103` is `ret`. -/
theorem tail_covers :
    coversPathAt true false gemv.prog gemv.fn_0 41 tailPs = true ∧
    coversPathAt true false gemv.prog gemv.fn_0 40 tailPs = false ∧
    coversPathWith false gemv.prog gemv.fn_0 41 tailPs = true ∧ (gS 45 0).exit = .ret := by
  decide +kernel

/-- The context: `ctx0` with gemv_kernel's program and one block of one thread: `%tid` and
`%ctaid` 0, `%ntid` and `%nctaid` 1 (the kernel declares `%ntid.x` in 1 to 1024, so `ctx0`'s 0
reads as `poison`), lane 0, thread 0 of block 0 as `ctx0`'s accesses name it; so the row
`(0 * 1 + 0) / 32` is 0. -/
def ctxG : Ctx :=
  { ctx0 with prog := gemv.prog, env := ⟨fun | .ntid, _ => 1 | .nctaid, _ => 1 | _, _ => 0, 0⟩ }

/-- The frame at statement 41 of gemv_kernel's `%6`, with no `alloca` block, no product and these
registers: `%0` (the output) pointing at the start of block 3, the row count `%10 = n`,
`%11 = 0`, and `%35` the vector of two `i32` zeros (so the row `%36` is 0). No other register is
set. -/
def frameG (n : Nat) : Frame :=
  ⟨gemv.fn_0, 6, 41,
    fun r => if r = 0 then some (.ptr ⟨3, 0⟩) else if r = 10 then some (.bits 64 n)
      else if r = 11 then some (.bits 64 0)
      else if r = 35 then some (.vec [.bits 32 0, .bits 32 0]) else none,
    fun _ => none, [], none⟩

/-- **The path's premises and its `ret` on one context, frame and memory**: from the entry
valuation of `frameG 0` under `ctxG` on `mem0`, every block's obligations hold, `%6` branches to
`%43` (row 0 is at least the row count 0), and `%103`'s `ret` runs (`RetWith false`). The kernel
evaluates all of it. -/
theorem tail_ret :
    RetWith false (Valuation.entry ctxG 0 mem0 (frameG 0)) (fun _ => True) tailPs := by
  refine ⟨?_, ?_, run_ok ?_⟩ <;> decide +kernel

/-- **The mutant**: with the row count 1 (`frameG 1`), row 0 is below it, `%6` branches to `%44`,
and the path's premises fail. -/
theorem tail_mutant : ¬ WalkWith false (Valuation.entry ctxG 0 mem0 (frameG 1)) tailPs := by
  decide +kernel

/-- **The thread from the tail of `%6` runs to its end**: for the context `ctxG`, the thread whose
one frame is `frameG 0` (step count 0) and the memory `mem0`, the thread runs to its end
(`Runs.of_retAt` with the flag on, from `tail_covers` and `tail_ret`). -/
theorem tail_runs : ∃ me, Runs ctxG ⟨[frameG 0], 0⟩ mem0 me :=
  let ⟨_, h, _⟩ := Runs.of_retAt (alloca := true) (P := gemv.prog) (c := ctxG)
    (t := ⟨[frameG 0], 0⟩) (f := frameG 0) rfl tail_covers.1 rfl rfl rfl rfl tail_ret
  ⟨_, h⟩

/-- The segments of gemv_kernel's `%6` from statement 0 with the `alloca` flag, at the stops
`gemvStops` (the shuffles at 17 and 18 and the nine lifetime markers), and the summary of the
rest, statements 41 to the branch (`summarizePieces`, `gemv_segs_alloca`). -/
def gP : List Piece × Summary :=
  (summarizePieces gemv.prog gemv.fn_0 6 0 gemvStops true).get (by decide +kernel)

/-- `gP` is the segment checker's result. -/
theorem gP_eq : summarizePieces gemv.prog gemv.fn_0 6 0 gemvStops true = some gP :=
  (Option.some_get _).symm

/-- The frame at statement 0 of gemv_kernel's `%6`, with no `alloca` block, no product and these
registers: the output `%0` and the inputs `%1` and `%2` pointing at the starts of blocks 3, 1
and 2, the row count `%3 = n` and `%4 = %5 = 0`, all `i32`. -/
def frameS (n : Nat) : Frame :=
  ⟨gemv.fn_0, 6, 0,
    fun r => if r = 0 then some (.ptr ⟨3, 0⟩) else if r = 1 then some (.ptr ⟨1, 0⟩)
      else if r = 2 then some (.ptr ⟨2, 0⟩) else if r = 3 then some (.bits 32 n)
      else if r = 4 then some (.bits 32 0) else if r = 5 then some (.bits 32 0) else none,
    fun _ => none, [], none⟩

/-- The memory at the first shuffle: `mem0` with the first segment's effects, its three
`alloca` blocks, from `frameS 0`'s entry valuation. -/
def memW : Mem :=
  let V := Valuation.entry ctxG 0 mem0 (frameS 0)
  match gP.1 with
  | .coll S :: _ => (SEff.run V (vals V S.nodes) S.effs).toOption.getD mem0
  | _ => mem0

/-- What the two shuffles deliver: the row's halves `%24 = %25 = 0`, on `memW`. -/
def dsG : List (Option Val × Mem) := [(some (.bits 32 0), memW), (some (.bits 32 0), memW)]

/-- `RetWith contract V (fun _ => True) ps` as a Boolean: the path's premises and `ret` exit
from `V`, and its last block's effects run; `false` for the empty path. -/
def retB (contract : Bool) : List (Nat × List Cond × Summary) → Valuation → Bool
  | [], _ => false
  | (l, ds, S) :: E, V =>
    let W := V.lastWith contract l S E
    decide (WalkWith contract V ((l, ds, S) :: E) ∧ W.2.2.exit = .ret) &&
      match SEff.run W.1 (vals W.1 W.2.2.nodes) W.2.2.effs with
      | .ok _ => true
      | .error _ => false

/-- `retB` gives `RetWith`, for every flag, path and valuation. -/
theorem retB_ret {contract : Bool} {ps : List (Nat × List Cond × Summary)} {V : Valuation}
    (h : retB contract ps V = true) : RetWith contract V (fun _ => True) ps := by
  cases ps with
  | nil => simp [retB] at h
  | cons x E =>
    obtain ⟨l, ds, S⟩ := x
    simp only [retB, Bool.and_eq_true, decide_eq_true_eq] at h
    obtain ⟨⟨h1, h2⟩, h3⟩ := h
    refine ⟨h1, h2, ?_⟩
    split at h3
    · exact ⟨_, ‹_›, trivial⟩
    · cases h3

/-- **gemv_kernel's `%6` from statement 0 to `ret`, through its `alloca`s, shuffles and lifetime
markers**: for the context `ctxG`, the thread whose one frame is `frameS 0` (step count 0) on
`mem0`, with the shuffles delivering `dsG`, the thread runs through the two waits to its end
(`RunsVia`). The segments run by `Piece.throughTo` to statement 41, and from there to `ret` on the
`%43` branch by `Runs.of_retAt` with the flag on (`tail_covers`); `RunsVia.of_fires` joins them,
and the kernel decides the segments' premises (`Piece.fires`, with `retB false tailPs` at
statement 41). -/
theorem gemv_runs : RunsVia ctxG (fun _ => True)
    [(fun _ _ _ _ => True, (some (.bits 32 0), memW)),
      (fun _ _ _ _ => True, (some (.bits 32 0), memW))] ⟨[frameS 0], 0⟩ mem0 :=
  RunsVia.of_fires (ds := dsG) (fn := gemv.fn_0) (F := retB false tailPs) (ws := [])
    (d₀ := (none, mem0))
    (K := fun t m f => RetWith false (Valuation.entry ctxG t.k m f) (fun _ => True) tailPs →
      ∃ m', Runs ctxG t m m' ∧ True) (Ss := gP.1) (p := 0)
    (fun _ _ _ hK hF => hK (retB_ret hF))
    (Piece.throughTo (P := gemv.prog) (alloca := true) (ps := gemvStops) (p0 := 0) (Ss := gP.1)
      (L := gP.2) rfl gP_eq (fun _ _ _ ht hfn hl hp hR =>
        let ⟨_, h, _⟩ := Runs.of_retAt (alloca := true) (P := gemv.prog) rfl tail_covers.1 ht hfn
          hl (hp.trans rfl) hR
        ⟨_, h, trivial⟩) _ rfl rfl rfl rfl) rfl rfl (by decide +kernel)

/-- **The mutants of `gemv_runs`**: with the row count 1 (`frameS 1`), row 0 is below it, `%6`
branches to `%44`, and `retB` fails at statement 41; with the shuffles delivering `mem0`, which
has no `alloca` block, the first lifetime marker's pointer is into no block the thread owns. The
kernel decides both. -/
theorem gemv_runs_mutant :
    Piece.fires gemv.fn_0 6 (retB false tailPs) gP.1 0 dsG
      (Valuation.entry ctxG 0 mem0 (frameS 1)) = false ∧
    Piece.fires gemv.fn_0 6 (retB false tailPs) gP.1 0
      [(some (.bits 32 0), mem0), (some (.bits 32 0), mem0)]
      (Valuation.entry ctxG 0 mem0 (frameS 0)) = false := by
  decide +kernel

/-- The summary of gemv_kernel's block `l` from position `p` with both flags, `alloca` and
`contract` (`summarizeAt true … true`, the exit from `SState.exitAt`). It is the default summary
when there is none. -/
def gC (l p : Nat) : Summary :=
  (summarizeAt true gemv.prog gemv.fn_0 l p (fun σ tm => σ.exitAt gemv.fn_0 l tm) true).getD
    default

/-- Block `l` of gemv_kernel from position `p`: its label, `gC`'s obligations and summary. -/
def gB (l p : Nat) : Nat × List Cond × Summary := (l, (gC l p).obls, gC l p)

/-- The rest of a round through the arm `%70`: `%58`, `%60`, `%70`, then `%76` from position 1. -/
def armA : List (Nat × List Cond × Summary) := [gB 62 0, gB 64 0, gB 74 0, gB 57 1]

/-- The rest of a round through the arm `%75`: `%58`, `%60`, `%75`, then `%76` from position 1. -/
def armB : List (Nat × List Cond × Summary) := [gB 62 0, gB 64 0, gB 75 0, gB 57 1]

/-- The rest of the path out of the loop: `%59`, `%78` from position 1, `%100`, `%102` and
`%103`. -/
def outP : List (Nat × List Cond × Summary) :=
  [gB 63 0, gB 65 1, gB 101 0, gB 103 0, gB 45 0]

/-- The loop at `%54` from position 2 whose rounds take the arm `%70`, with the path out
`outP`. -/
def loopA : LoopSeg := ⟨55, 2, (gC 55 2).obls, gC 55 2, armA, outP, []⟩

/-- The loop at `%54` whose rounds take the arm `%75`. -/
def loopB : LoopSeg := { loopA with B := armB }

/-- Two loops at the header `%54`: rounds through `%70` and, as the first loop's path out, one
round through `%75`; then the rounds through `%75` and the path out of `loopB`. -/
def twoArms : List LoopSeg := [{ loopA with X := armB }, loopB]

/-- A loop whose path out is cut after `%59`, whose exit is a `br` to `%78`. -/
def cut (L : LoopSeg) : LoopSeg := { L with X := [gB 63 0] }

/-- **The checker accepts a round through either arm** (`LoopSeg.coversRoundAt` with both
flags): the round through `%70` and the round through `%75`. Without the `contract` flag it
refuses the round through `%70`, whose `fmul contract` and `fadd contract` it does not take. -/
theorem loop_rounds :
    LoopSeg.coversRoundAt true true gemv.prog gemv.fn_0 loopA = true ∧
    LoopSeg.coversRoundAt true true gemv.prog gemv.fn_0 loopB = true ∧
    LoopSeg.coversRoundAt true false gemv.prog gemv.fn_0 loopA = false := by
  decide +kernel

/-- **The chain checker refuses gemv's loop with its path out** (`coversChainAt true true`,
from statement 41 of `%6` through `%44`): through either arm and as `twoArms`. The block checker
has no summary of `%78` from position 1, because its shuffles are collectives. -/
theorem loop_refused :
    coversChainAt true true gemv.prog gemv.fn_0 41 6 (gC 6 41).obls (gC 6 41) [gB 44 0]
      [loopA] = false ∧
    coversChainAt true true gemv.prog gemv.fn_0 41 6 (gC 6 41).obls (gC 6 41) [gB 44 0]
      [loopB] = false ∧
    coversChainAt true true gemv.prog gemv.fn_0 41 6 (gC 6 41).obls (gC 6 41) [gB 44 0]
      twoArms = false ∧
    (summarizeAt true gemv.prog gemv.fn_0 65 1 (fun σ tm => σ.exitAt gemv.fn_0 65 tm)
      true).isNone := by
  decide +kernel

/-- **With the path out cut after `%59`, the chain checker accepts the loop**: through either arm,
and as `twoArms` with its last path out cut (the `%70` rounds, then the `%75` rounds). -/
theorem loop_arms :
    coversChainAt true true gemv.prog gemv.fn_0 41 6 (gC 6 41).obls (gC 6 41) [gB 44 0]
      [cut loopA] = true ∧
    coversChainAt true true gemv.prog gemv.fn_0 41 6 (gC 6 41).obls (gC 6 41) [gB 44 0]
      [cut loopB] = true ∧
    coversChainAt true true gemv.prog gemv.fn_0 41 6 (gC 6 41).obls (gC 6 41) [gB 44 0]
      [{ loopA with X := armB }, cut loopB] = true := by
  decide +kernel

/-- The positions of `%78`'s five `shfl.sync.bfly`s: statements 2, 6, 10, 14 and 18. -/
def bflyStops : List Nat := [2, 6, 10, 14, 18]

/-- The segments of gemv_kernel's `%78` from position 1, after its `phi`, with the `alloca` flag,
at the five shuffles `bflyStops`, and the summary of the rest, statements 19 to its branch
(`summarizePieces`). Each segment ends at a shuffle: the first is the `bitcast` of `%79`, each
other the `bitcast` of the shuffle's value, its `fadd contract` and the next `bitcast`. -/
def bP : List Piece × Summary :=
  (summarizePieces gemv.prog gemv.fn_0 65 1 bflyStops true).get (by decide +kernel)

/-- `bP` is the segment checker's result. -/
theorem bP_eq : summarizePieces gemv.prog gemv.fn_0 65 1 bflyStops true = some bP :=
  (Option.some_get _).symm

/-- The path from `%78`'s statement 19, after its last shuffle, to `ret` on lane 0: `%78`, `%100`
(its `store` of the sum `%99` through `%37`), `%102` and `%103` (locals 65, 101, 103 and 45), each
block with its summary with both flags (`gB`). -/
def bflyOut : List (Nat × List Cond × Summary) := [gB 65 19, gB 101 0, gB 103 0, gB 45 0]

/-- **The checkers accept `%78`'s schedule through its five shuffles and the path after it**: the
segment checker summarizes `%78` from position 1 at the five shuffles (five collective segments),
and the path checker with both flags accepts `bflyOut` from statement 19. -/
theorem bfly_covers :
    bP.1.length = 5 ∧ coversPathAt true true gemv.prog gemv.fn_0 19 bflyOut = true := by
  decide +kernel

/-- What the five shuffles deliver: each the `i32` 0, on memory `m`. -/
def dsB (m : Mem) : List (Option Val × Mem) := List.replicate 5 (some (.bits 32 0), m)

/-- The premises at `%78`'s position 1: `Piece.fires` of `bP` with the deliveries `dsB m` and the
final check `retB true bflyOut` at statement 19. -/
def atB (m : Mem) (V : Valuation) : Prop :=
  Piece.fires gemv.fn_0 65 (retB true bflyOut) bP.1 1 (dsB m) V = true

/-- `atB` is decided by evaluating `Piece.fires`. -/
instance (m : Mem) : DecidablePred (atB m) := fun _ => inferInstanceAs (Decidable (_ = true))

/-- The chain from statement 41 of `%6` with no round of the loop at `%54`, into `%78` at
position 1, as a Boolean at valuation `V`: the edge from `%6` through `%44` into the header at
position 2, the edge of the path out `%59` into `%78` at position 1, and `atB m` there. -/
def chainB (m : Mem) (V : Valuation) : Bool :=
  let W := Valuation.roundWith true 6 (gC 6 41) [gB 44 0] V
  decide (EdgeWith true 55 2 V 6 (gC 6 41).obls (gC 6 41) [gB 44 0] ∧
    EdgeWith true 65 1 W 55 (gC 55 2).obls (gC 55 2) [gB 63 0] ∧
    atB m (Valuation.roundWith true 55 (gC 55 2) [gB 63 0] W))

/-- `chainB` gives the chain through `cut loopA` with no round, whose last path out stops after
its edge into `%78` at position 1 (`ChainWith.of_rounds` at 0 rounds), for every memory and
valuation. -/
theorem chainB_chain {m : Mem} {V : Valuation} (h : chainB m V = true) :
    ChainWith true (BackWith true 65 1 (atB m)) [cut loopA] V 6 (gC 6 41).obls (gC 6 41)
      [gB 44 0] := by
  simp only [chainB, decide_eq_true_eq] at h
  exact ChainWith.of_rounds (L := cut loopA) rfl 0 ⟨h.1, fun _ h => absurd h (Nat.not_lt_zero _)⟩
    (ChainWith.last h.2)

/-- **gemv_kernel from statement 41 of `%6` through the loop at `%54`, the five butterfly
shuffles of `%78` and its store, to `ret`**: for the context `ctxG`, every memory `m` of the
deliveries, and every thread `t` on memory `mt` whose one frame `f` is at `%6`'s statement 41
with the chain through `cut loopA` into `%78` at position 1 at its entry valuation (`chainB`
gives it), with the five shuffles delivering `dsB m`, the thread runs through the five waits to
its end (`RunsVia`). The chain stops after `%59`'s edge into `%78` (`RunsVia.of_chain`, accepted
by `loop_arms`); from there the segments run through the shuffles (`Piece.throughTo`,
`RunsVia.of_fires`), and from statement 19 the path `bflyOut` runs to `ret` (`Runs.of_retAt` with
both flags). -/
theorem bfly_at (m : Mem) {t : Thread} {mt : Mem} {f : Frame} (ht : t.frames = [f])
    (hfn : f.fn = gemv.fn_0) (hl : f.label = 6) (hp : f.pc = 41)
    (h : ChainWith true (BackWith true 65 1 (atB m)) [cut loopA] (Valuation.entry ctxG t.k mt f)
      6 (gC 6 41).obls (gC 6 41) [gB 44 0]) :
    RunsVia ctxG (fun _ => True) ((dsB m).map fun d => (fun _ _ _ _ => True, d)) t mt :=
  RunsVia.of_chain (alloca := true) (contract := true) (P := gemv.prog) (d := 65) (q := 1) rfl
    loop_arms.1
    (fun t m' f ht hfn hl hp hJ => by
      rw [← List.append_nil ((dsB m).map _)]
      exact RunsVia.of_fires (ds := dsB m) (fn := gemv.fn_0) (F := retB true bflyOut) (ws := [])
        (d₀ := (none, mem0))
        (K := fun t m f => RetWith true (Valuation.entry ctxG t.k m f) (fun _ => True) bflyOut →
          ∃ m', Runs ctxG t m m' ∧ True) (Ss := bP.1) (p := 1)
        (fun _ _ _ hK hF => hK (retB_ret hF))
        (Piece.throughTo (P := gemv.prog) (alloca := true) (ps := bflyStops) (p0 := 1)
          (Ss := bP.1) (L := bP.2) rfl bP_eq (fun _ _ _ ht hfn hl hp hR =>
            let ⟨_, h, _⟩ := Runs.of_retAt (alloca := true) (contract := true) (P := gemv.prog)
              rfl bfly_covers.2 ht hfn hl (hp.trans rfl) hR
            ⟨_, h, trivial⟩) _ ht hfn hl hp) hfn hp hJ)
    ht hfn hl hp h

/-- **`bfly_at` at `frameG 1`**: the row count 1, so `%6` branches to `%44`, and `%11 = 0`, so the
trip bound `%53` is 0; the deliveries on `mem0`. The kernel decides `chainB`. -/
theorem bfly_runs :
    RunsVia ctxG (fun _ => True) ((dsB mem0).map fun d => (fun _ _ _ _ => True, d))
      ⟨[frameG 1], 0⟩ mem0 :=
  bfly_at mem0 rfl rfl rfl rfl (chainB_chain (by decide +kernel))

/-- **gemv_kernel's `%6` from statement 0 through the loop at `%54` and `%78`'s five shuffles to
`ret`**: for the context `ctxG`, the thread whose one frame is `frameS 1` (row count 1, `K = 0`)
on `mem0`, with `%6`'s two shuffles delivering `dsG` and `%78`'s five delivering `dsB memW`, the
thread runs through the seven waits to its end (`RunsVia`). `%6`'s segments run by
`Piece.throughTo` to statement 41, and from there `bfly_at`; `RunsVia.of_fires` joins them with
`%78`'s waits after `%6`'s, and the kernel decides `Piece.fires` with `chainB memW` at statement
41. -/
theorem gemv_loop_runs : RunsVia ctxG (fun _ => True)
    (dsG.map (fun d => (fun _ _ _ _ => True, d)) ++
      (dsB memW).map fun d => (fun _ _ _ _ => True, d)) ⟨[frameS 1], 0⟩ mem0 :=
  RunsVia.of_fires (ds := dsG) (fn := gemv.fn_0) (F := chainB memW) (lbl := 6) (f := frameS 1)
    (ws := (dsB memW).map fun d => (fun _ _ _ _ => True, d)) (d₀ := (none, mem0))
    (K := fun t m f => ChainWith true (BackWith true 65 1 (atB memW)) [cut loopA]
        (Valuation.entry ctxG t.k m f) 6 (gC 6 41).obls (gC 6 41) [gB 44 0] →
      RunsVia ctxG (fun _ => True) ((dsB memW).map fun d => (fun _ _ _ _ => True, d)) t m)
    (Ss := gP.1) (p := 0)
    (fun _ _ _ hK hF => hK (chainB_chain hF))
    (Piece.throughTo (P := gemv.prog) (alloca := true) (ps := gemvStops) (p0 := 0) (Ss := gP.1)
      (L := gP.2) rfl gP_eq (fun t m f ht hfn hl hp hC =>
        bfly_at (t := t) (mt := m) (f := f) memW ht hfn hl (hp.trans rfl) hC) _ rfl rfl rfl rfl)
    rfl rfl (by decide +kernel)

/-- **The mutants of `bfly_runs` and `gemv_loop_runs`**: with the row count 0 (`frameG 0`) `%6`
branches to `%43`, so the chain's first edge into the loop's header fails; with four deliveries,
one shuffle has none, and `atB`'s check fails; from statement 0 with the row count 0
(`frameS 0`), `chainB` fails at statement 41. The kernel decides all three. -/
theorem bfly_mutant :
    ¬ EdgeWith true 55 2 (Valuation.entry ctxG 0 mem0 (frameG 0)) 6 (gC 6 41).obls (gC 6 41)
      [gB 44 0] ∧
    Piece.fires gemv.fn_0 65 (retB true bflyOut) bP.1 1 ((dsB mem0).take 4)
      (Valuation.roundWith true 55 (gC 55 2) [gB 63 0]
        (Valuation.roundWith true 6 (gC 6 41) [gB 44 0]
          (Valuation.entry ctxG 0 mem0 (frameG 1)))) = false ∧
    Piece.fires gemv.fn_0 6 (chainB memW) gP.1 0 dsG
      (Valuation.entry ctxG 0 mem0 (frameS 0)) = false := by
  decide +kernel

end MojoProofTest.SymGemvTail
