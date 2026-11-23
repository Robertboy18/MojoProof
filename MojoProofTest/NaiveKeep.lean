import MojoProofTest.NaiveSound

/-!
# A twin of the naive loop whose round loads through a register the round sets

`fnK` is the function of the naive matmul kernel (`naive`, MojoProofTest/SymPhi.lean) with the
address of `A`'s element (`%56` to `%59` of the latch `%52`) computed in the body `%50` instead:
the latch's load `%60` reads through `%59`, a register that a block of the loop path sets, so the
loop does not keep it (`Func.keeps`). Every other block is `naive`'s.

* `loopK` and `chainK`: the loop `%46 → %50 → %52` of `fnK` (the header and the path out are
  `naiveL`'s, MojoProofTest/SymNaive.lean) and the chain into it from the first block (`chainN`'s
  path in, MojoProofTest/NaiveThread.lean); `chainK_covers`: the path checker with
  `fmul contract` accepts it.
* `loopK_bases`: the registers that the loop keeps and that some load of its loop path reads
  through are `%12` alone (`LoopSeg.bases`), and the loop path does not read memory only through
  them (`LoopSeg.loadsFrom`), at `%60`.
* The refusal of `naiveK.runInv` (`mojo_kernel`'s `mat … inv` clause,
  MojoProof/Sym/KernelCmd.lean): `Mat.Head.iterate`'s premise `LoopSeg.loadsFrom` at
  `LoopSeg.bases` fails, so the clause does not prove `Mat.Head` at the heads of the rounds. The
  command evaluates it before the attempt, and the refusal names the premise, `%12` and the block
  `%52` of the load `%60`. The edge into the loop and `Mat.Head` at the loop head are `naive`'s.

`fnO` is `naive`'s function with the latch's address `%59` in the output's pointer `%10` instead
of `A`'s `%11`: the loop keeps `%10` and reads memory only through registers it keeps, but `%10` at
the loop head is a pointer to the output's block.

* `loopO_bases`: the loop's `LoopSeg.bases` are `%10` and `%12`, and `LoopSeg.loadsFrom` holds at
  them.
* The refusal of `naiveW.runInv`: the clause proves each register of `LoopSeg.bases` at the loop
  head a pointer to an input by `obl_have` and `a ≠ o`, `b ≠ o` (`Mat.Head.iterate`'s premise
  that their values name only blocks other than the output's); at `%10`, which names the output's
  block, that fails, and the refusal names the premise and `%10`, with the goal `bC ≠ bC`.

Each result covers the one function `fnK` or `fnO`, not all programs.
-/

namespace MojoProofTest.NaiveKeep

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.NaiveThread

/-- The body `%50` of `fnK`: the statements `%56` to `%59` of `naive`'s latch (the trunc of the
counter `%47`, the index into `A`'s row, its sext and the address `%59` in `%11`), then
`naive`'s `br label %52`. -/
def bodyB : LLVM.Block :=
  ⟨naive.fn_0.b_4.label, naive.fn_0.b_6.stmts.extract 3 7, naive.fn_0.b_4.term⟩

/-- The latch `%52` of `fnK`: `naive`'s latch without `%56` to `%59`, so its load `%60` reads
through the register `%59` that `bodyB` sets. -/
def latchB : LLVM.Block :=
  ⟨naive.fn_0.b_6.label, naive.fn_0.b_6.stmts.extract 0 3 ++ naive.fn_0.b_6.stmts.extract 7 14,
    naive.fn_0.b_6.term⟩

/-- `naive.fn_0` with the body `bodyB` and the latch `latchB`. -/
def fnK : Func :=
  { naive.fn_0 with blocks := #[naive.fn_0.b_0, naive.fn_0.b_1, naive.fn_0.b_2, naive.fn_0.b_3,
      bodyB, naive.fn_0.b_5, latchB, naive.fn_0.b_7, naive.fn_0.b_8] }

/-- The summary of `bodyB` from position 0. -/
sym_summary bodyK := naive.prog fnK naive.fn_0.b_4.label 0

/-- The summary of `latchB` from position 0 with `fmul contract` in the fragment (`summarizeC`;
the default summary if it refuses, which `chainK_covers` excludes). -/
def latchK : Summary := (summarizeC naive.prog fnK naive.fn_0.b_6.label 0).getD default

/-- The loop `%46 → %50 → %52` of `fnK`: `naiveL`'s header `hdr` from position 2 and path out
`trip0`, with the body `bodyK` and the latch `latchK`; no loop is nested in it. -/
def loopK : LoopSeg :=
  ⟨naive.fn_0.b_3.label, 2, hdr.obls, hdr,
    [(naive.fn_0.b_4.label, bodyK.obls, bodyK), (naive.fn_0.b_6.label, latchK.obls, latchK)],
    trip0, []⟩

/-- The chain of `fnK`: `chainN`'s path `%6 → %45` into the loop `loopK`. -/
def chainK : LoopChain := ⟨chainN.l, chainN.ds, chainN.S, chainN.E, [loopK]⟩

/-- The path checker with `fmul contract` accepts `chainK` from `fnK`'s first block. -/
theorem chainK_covers : coversChainsWith true naive.prog fnK [chainK] = true := by
  decide +kernel

/-- **The loop does not read memory only through registers it keeps**: of the registers `loopK`
keeps, `%12` alone is the base of a load's address in its loop path (`LoopSeg.bases`; `%60`
reads through `%59`, which `bodyK` sets), and `LoopSeg.loadsFrom` at `[%12]` fails. -/
theorem loopK_bases :
    LoopSeg.bases fnK loopK = [idx "12"] ∧ LoopSeg.loadsFrom fnK loopK [idx "12"] = false := by
  decide +kernel

/--
error: mojo_kernel: mat: inv: naiveK.runInv does not elaborate: `Mat.Head.iterate`'s premise `LoopSeg.loadsFrom` at `LoopSeg.bases` (%12) is false: block %52 of the loop path loads through a pointer whose base is not a register the loop keeps (fnK)
-/
#guard_msgs in
mojo_kernel naiveK := naive.prog fnK reads bA := a1, bB := a2 writes bC := a0
  scalars m := a3, n := a4, K := a5 contract mat [skipN] [chainK] inv

/-- The statement `s` with the base of its address, if it is a `getelementptr`, the local
`%10` (the output's pointer). -/
def rebase (s : Stmt) : Stmt :=
  match s with
  | ⟨r, .gep fl t (.mk ty _) ix, md⟩ => ⟨r, .gep fl t (.mk ty (.loc (idx "10"))) ix, md⟩
  | s => s

/-- The latch `%52` of `fnO`: `naive`'s latch with the address `%59` in `%10`. -/
def latchOB : LLVM.Block := { naive.fn_0.b_6 with stmts := naive.fn_0.b_6.stmts.modify 6 rebase }

/-- `naive.fn_0` with the latch `latchOB`. -/
def fnO : Func :=
  { naive.fn_0 with blocks := #[naive.fn_0.b_0, naive.fn_0.b_1, naive.fn_0.b_2, naive.fn_0.b_3,
      naive.fn_0.b_4, naive.fn_0.b_5, latchOB, naive.fn_0.b_7, naive.fn_0.b_8] }

/-- The summary of `latchOB` from position 0 with `fmul contract` in the fragment (`summarizeC`;
the default summary if it refuses, which `chainO_covers` excludes). -/
def latchO : Summary := (summarizeC naive.prog fnO naive.fn_0.b_6.label 0).getD default

/-- The loop `%46 → %50 → %52` of `fnO`: `naiveL` with the latch `latchO`. -/
def loopO : LoopSeg :=
  ⟨naive.fn_0.b_3.label, 2, hdr.obls, hdr,
    [(naive.fn_0.b_4.label, SymNaive.body.obls, SymNaive.body),
      (naive.fn_0.b_6.label, latchO.obls, latchO)], trip0, []⟩

/-- The chain of `fnO`: `chainN`'s path `%6 → %45` into the loop `loopO`. -/
def chainO : LoopChain := ⟨chainN.l, chainN.ds, chainN.S, chainN.E, [loopO]⟩

/-- The path checker with `fmul contract` accepts `chainO` from `fnO`'s first block. -/
theorem chainO_covers : coversChainsWith true naive.prog fnO [chainO] = true := by
  decide +kernel

/-- **The loop reads memory only through registers it keeps**, `%10` and `%12`
(`LoopSeg.bases`, `LoopSeg.loadsFrom`). -/
theorem loopO_bases :
    LoopSeg.bases fnO loopO = [idx "10", idx "12"] ∧
      LoopSeg.loadsFrom fnO loopO [idx "10", idx "12"] = true := by
  decide +kernel

/--
error: mojo_kernel: mat: inv: naiveW.runInv does not elaborate: `Mat.Head.iterate`'s premise on the registers `LoopSeg.bases` fails at %10: its value at the loop head is not shown to name a block other than the output's by `hne` (`a` or `b` other than the output) (fnO): ⊢ bC ≠ bC
-/
#guard_msgs in
mojo_kernel naiveW := naive.prog fnO reads bA := a1, bB := a2 writes bC := a0
  scalars m := a3, n := a4, K := a5 contract mat [skipN] [chainO] inv

end MojoProofTest.NaiveKeep
