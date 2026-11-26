import MojoProofTest.SymLane
import MojoProofTest.SymSeg
import MojoProof.Sym.OblSeg

/-!
# gemv_kernel's checkers' facts: the `%43` branch, the loop at `%54` and `%78`

gemv_kernel's entry block `%6` (fixture `gemv`, MojoProofTest/SymLane.lean) starts with three
`alloca`s and calls two shuffles (statements 17 and 18) and lifetime markers (statements 19 to
40). The block checker refuses the block from statement 0 even with the `alloca` flag
(`gemv_allocas_twin`, MojoProofTest/SymAlloca.lean); the segment checker runs it to its branch
(`gemv_segs_alloca`, MojoProofTest/SymSeg.lean; `gP` here). The path checker with the flag on
(`coversPathAt true`) takes the block from statement 41, after its last marker, through the
branch to `%43`, the branch taken when the row `%36` (the warp's lane 0's, which the two shuffles
broadcast, not the lane's own `%20`) is at least the row count `%10`, and `%43`'s `br` to `%103`,
`ret void`. The parser numbers locals by first appearance, so `%103` is local 45
(its first use is `%43`'s `br`); `%6` and `%43` are locals 6 and 43.

* `tail_covers`: the path checker with the flag accepts the path from statement 41 and refuses it
  from statement 40 (the `lifetime.end` of `%9`). None of the path's blocks has an `alloca`, so
  the checker without the flag (`coversPathWith`) accepts it too. The last block's exit is `ret`.

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
  (`bflyOut`). `at78 a n` is the valuation at `%78`'s position 1 after `n` rounds of the loop
  through one arm (`lp a`: `%70` if `a`, else `%75`).

The runs of whole warps from `Grid.start` through these blocks are in MojoProofTest/GemvWarp.lean.
-/

namespace MojoProofTest.SymGemvTail

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.SymRun MojoProofTest.SymSeg

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

/-- The segments of gemv_kernel's `%6` from statement 0 with the `alloca` flag, at the stops
`gemvStops` (the shuffles at 17 and 18 and the nine lifetime markers), and the summary of the
rest, statements 41 to the branch (`summarizePieces`, `gemv_segs_alloca`). -/
def gP : List Piece × Summary :=
  (summarizePieces gemv.prog gemv.fn_0 6 0 gemvStops true).get (by decide +kernel)

/-- `gP` is the segment checker's result. -/
theorem gP_eq : summarizePieces gemv.prog gemv.fn_0 6 0 gemvStops true = some gP :=
  (Option.some_get _).symm

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

/-- The loop at `%54` with its path out cut after `%59`, whose rounds take the arm `%70` if `a`
and `%75` if not: `cut loopA` and `cut loopB` as one function of the arm. -/
def lp (a : Bool) : LoopSeg := cut (if a then loopA else loopB)

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

/-- The header's valuation after `i` rounds of the loop `lp a` from valuation `V` at statement 41
of `%6`: the `i`-th iterate of the round (`Valuation.roundWith` of the header and the arm) from
the edge from `%6` through `%44` into the header at position 2. -/
def hd (a : Bool) (i : Nat) (V : Valuation) : Valuation :=
  (Valuation.roundWith true (lp a).h (lp a).H (lp a).B)^[i]
    (Valuation.roundWith true 6 (gC 6 41) [gB 44 0] V)

/-- The valuation at `%78`'s position 1 from valuation `V` at statement 41 of `%6` after `n`
rounds of the loop `lp a` (`hd a n V`), then the edge of the path out `%59` into `%78`. At
`n = 0` it is the two edges alone. -/
def at78 (a : Bool) (n : Nat) (V : Valuation) : Valuation :=
  Valuation.roundWith true (lp a).h (lp a).H (lp a).X (hd a n V)

end MojoProofTest.SymGemvTail
