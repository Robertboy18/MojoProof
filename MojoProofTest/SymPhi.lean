import MojoProofTest.SymRun

/-!
# `Block.sound_retWith` on edges into `phi` blocks: the naive matmul kernel's, and `br i1`'s

`naive` is `matmul_kernel_naive_float32_float32_float32_True_16_16826c8c`
(tests/corpus/mgemm/), imported here only. Its loop header `%46` starts with two `phi`s, the
counter `%47` and the accumulator `%48`; its exit `%51` branches into `%67`, which starts with
`%68 = phi float [%48, %51]`, stores `%68` to `%40` and branches to `%69` (`ret void`). The block
checker refuses `%67` from position 0, before its `phi`.

* `hdr`, `out`, `fin`: the summaries of `%46` from position 2 (after its `phi`s: the
  `icmp slt %47, %16` and the branch to `%50` or `%51`), of `%51` (a `br` into `%67`:
  `Exit.phi`, with the obligation that `%48` evaluates) and of `%67` from position 1 (after its
  `phi`: the store). `%69`'s summary, `ret void` alone, is `Kernels.vadd.b3` (that of
  `vector_addition`'s `%31`, MojoProof/Kernels/Vadd.lean).
* `trip0_covers`: the path checker (`coversPathWith false`) accepts the path
  `%46 → %51 → %67 → %69` from position 2, the run of a thread whose loop runs no trip.
* `trip0_walk`: its premises (`WalkWith false`) hold under the context `ctxN` (`ctx0` of
  MojoProofTest/SymRun.lean with `naive`'s program), on memory `mem0`, at the frame `frameH 0`
  (`%46`'s position 2 with `%47 = 0`, `%48` the binary32 word of 1, the bound `%16 = 0` and `%40`
  pointing at `mem0`'s output block 3): the header's branch goes to `%51` (`0 < 0` fails), and
  the entry valuation of `%67` (`Valuation.into`) has `%68 = %48`, which `enter` sets.
* `trip0_cell`: `Block.sound_retWith` with these: the thread's steps from `frameH 0` run the path
  to its `ret`, the next step returns, and the output's cell 0 holds 1.
* `pre`, `pre_covers`: the summary of `%45`, whose `br` enters `%46` with the integer constant
  0 for `%47` and the float constant `0.0` for `%48`: the constant is its node 0
  (`SNode.flit`), and the path checker with `phi`s accepts `%45 → %46 → %51 → %67 → %69`.
* `trip0_twins`: `%45`'s certificate without node 0's obligation is refused; an edge
  `%50 → %67` is refused, since `%67`'s `phi` has no operand from `%50`; with the bound
  `%16 = 1` the header goes to `%50` and the premises fail; the block checker `covers` refuses
  `%67`'s summary from position 0, before its `phi`.

A `br i1` into blocks with `phi`s (`edgeF`, a function written here: block 0's `br i1` on
`%3` goes to block 1, whose `phi` takes the constant 7 from block 0, or to block 2, whose `phi`
takes the float constant 1.5):

* `entryB`, `entry_both`: the entry block's summary with both edges' obligations (`summarize`):
  block 2's constant 1.5 is its node 0, whose obligation holds at `frameE true`.
* `entryTo`: the entry block's summary for the edge into block 1 (`summarizeWith` with
  `SState.exitTo`), with the obligations of that edge only.
* `edge_covers`, `edge_walk`, `edge_run`: the path checker with `phi`s accepts the path `0 → 1`
  (the entry block by `coversTo`), its premises hold at `frameE true` (`%3 = 1`), and
  `Block.sound_retWith` runs the thread through the edge to block 1's `ret`.
* `edge_twins`: `coversTo` refuses `entryTo` without its first obligation and with none;
  the path `0 → 2` with `entryTo` is refused; with `%3 = 0` the premises of the path `0 → 1`
  fail.

A `ret` to a caller frame: `edge_back` runs the thread `[frameE true, callerE]` through the
callee's path `0 → 1`, back to the caller `callerE` after its call (position 1 of block 1, with
`%4 = 7`) and through the caller's block to its `ret` (`Block.sound_back`).

Each result covers the program, path, context, memory and frames named, not all programs.
-/

namespace MojoProofTest.SymPhi

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymRun
open FloatLib.Floats.Formats.BinaryInterchange

mojo_import "mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll"
  as naive

/-- The register number of the local `%n` of the naive kernel (0 when it has none). -/
def idx (n : String) : Nat :=
  ((List.range naive.fn_0.names.size).find? (naive.fn_0.names[·]? == some n)).getD 0

/-- The loop header `%46` from position 2, after its `phi`s. -/
sym_summary hdr := naive.prog naive.fn_0 naive.fn_0.b_3.label 2

/-- `%51`: a `br` into `%67`, which starts with a `phi`. -/
sym_summary out := naive.prog naive.fn_0 naive.fn_0.b_5.label 0

/-- `%67` from position 1, after its `phi`: the store of `%68` to `%40`. -/
sym_summary fin := naive.prog naive.fn_0 naive.fn_0.b_7.label 1

/-- The rest of the path of a thread whose loop runs no trip: `%51`, `%67`, `%69` (whose summary,
`ret void` alone, is `Kernels.vadd.b3`). -/
def trip0 : List (Nat × List Cond × Summary) :=
  [(naive.fn_0.b_5.label, out.obls, out), (naive.fn_0.b_7.label, fin.obls, fin),
    (naive.fn_0.b_8.label, Kernels.vadd.b3.obls, Kernels.vadd.b3)]

/-- The path checker with `phi`s accepts `%46 → %51 → %67 → %69` from `%46`'s position 2. -/
theorem trip0_covers :
    coversPathWith false naive.prog naive.fn_0 2
      ((naive.fn_0.b_3.label, hdr.obls, hdr) :: trip0) = true := by
  decide +kernel

/-- The context: `ctx0` with `naive`'s program. -/
def ctxN : Ctx := { ctx0 with prog := naive.prog }

/-- The frame at `%46`'s position 2 with the counter `%47 = 0`, the accumulator `%48` the
binary32 word of 1, the bound `%16 = n` and the output pointer `%40` at block 3. -/
def frameH (n : Nat) : Frame :=
  ⟨naive.fn_0, naive.fn_0.b_3.label, 2,
    fun r => if r = idx "47" then some (.bits 64 0)
      else if r = idx "48" then some (.bits 32 (BitVec.ofNat 32 0x3f800000))
      else if r = idx "16" then some (.bits 64 (BitVec.ofNat 64 n))
      else if r = idx "40" then some (.ptr ⟨3, 0⟩)
      else none,
    fun _ => none, [], none⟩

/-- **The path premises**: at `frameH 0` under `ctxN` on `mem0`, every block's obligations hold
under its entry valuation, the header's branch goes to `%51`, `%51`'s to `%67` and `%67`'s to
`%69`. -/
theorem trip0_walk :
    WalkWith false (Valuation.entry ctxN 0 mem0 (frameH 0))
      ((naive.fn_0.b_3.label, hdr.obls, hdr) :: trip0) := by
  decide +kernel

/-- **The output cell at the return**: the steps from `frameH 0` run `%46 → %51 → %67 → %69` to
its `ret`, the next step returns (`.done`), and cell 0 of the output holds the accumulator's
value 1 (`Block.sound_retWith` with `trip0_covers` and `trip0_walk`, and the kernel's evaluation
of the path's effects). -/
theorem trip0_cell : ∃ fe me,
    Steps ctxN ⟨[frameH 0], 0⟩ mem0 ⟨[fe], 0 + pathLen hdr trip0⟩ me ∧
    step ctxN ⟨[fe], 0 + pathLen hdr trip0⟩ me = .ok (.done me) ∧
    me.load naive.prog.layout ctxN.who 0 (.fp .float) ⟨3, 0⟩ (some 4) =
      .ok (.ofFloat .float (Model.ofNatBits 0x3f800000)) := by
  have hc :
      (match SEff.run ((Valuation.entry ctxN 0 mem0 (frameH 0)).lastWith false
            naive.fn_0.b_3.label hdr trip0).1
          (vals ((Valuation.entry ctxN 0 mem0 (frameH 0)).lastWith false naive.fn_0.b_3.label hdr
              trip0).1
            ((Valuation.entry ctxN 0 mem0 (frameH 0)).lastWith false
              naive.fn_0.b_3.label hdr trip0).2.2.nodes)
          ((Valuation.entry ctxN 0 mem0 (frameH 0)).lastWith false
            naive.fn_0.b_3.label hdr trip0).2.2.effs with
        | .ok me =>
          match me.load naive.prog.layout ctxN.who 0 (.fp .float) ⟨3, 0⟩ (some 4) with
          | .ok v => decide (v.float? .float = some (Model.ofNatBits 0x3f800000))
          | .error _ => false
        | .error _ => false) = true := by
    decide +kernel
  obtain ⟨fe, me, hS, hm, hst⟩ := Block.sound_retWith (c := ctxN) (t := ⟨[frameH 0], 0⟩)
    (m := mem0) (f := frameH 0) rfl trip0_covers rfl rfl rfl rfl trip0_walk rfl rfl
  rw [Valuation.allocsWith_nil _ trip0_covers, List.nil_append] at hst
  refine ⟨fe, me, hS, hst, ?_⟩
  erw [hm] at hc
  dsimp only at hc
  split at hc
  next v hv => rw [hv, Val.float?_eq_some.1 (of_decide_eq_true hc)]
  next => exact absurd hc (by decide)

/-- `%45`, the loop's preheader, from position 0: `br label %46`, whose `phi`s take the
integer constant 0 for `%47` and the float constant `0.000000e+00` for `%48`. -/
sym_summary pre := naive.prog naive.fn_0 naive.fn_0.b_2.label 0

/-- **The preheader**: `%45`'s summary has one node, the float constant `0.0` at type `float`
(`SNode.flit`, from `SState.start`), and the obligations that the edge's operands (the word 0
for `%47`, node 0 for `%48`) evaluate and that its effects (none) run; the path checker with
`phi`s accepts `%45 → %46 → %51 → %67 → %69` from position 0. The premises of `%45` and its
edge hold at every valuation of `naive`'s function (`SymNaive.pre_edge`,
MojoProofTest/SymNaive.lean). -/
theorem pre_covers :
    pre.nodes = [.flit .float (.dec false "0" "000000" 0)] ∧
    pre.obls = [.ok (.int 64 0), .ok (.node 0), .mem []] ∧
    coversPathWith false naive.prog naive.fn_0 0
      ((naive.fn_0.b_2.label, pre.obls, pre) :: (naive.fn_0.b_3.label, hdr.obls, hdr) :: trip0) =
      true := by
  decide +kernel

/-- **The twins**: `%45`'s certificate without the obligation that node 0 (the float constant
`0.0`) evaluates is refused; `%67`'s `phi` has no operand from `%50`, so an edge `%50 → %67` is
refused (`SState.phiConds` gives `none`); with the bound `%16 = 1` the header goes to `%50`,
and the premises of the path through `%51` fail; the block checker `covers` refuses `%67`'s
summary `fin` from position 0, before its `phi`. -/
theorem trip0_twins :
    covers naive.prog naive.fn_0 naive.fn_0.b_2.label 0 (pre.obls.erase (.ok (.node 0))) pre =
      false ∧
    (SState.init.phiConds naive.fn_0 naive.fn_0.b_4.label naive.fn_0.b_7.label).isNone = true ∧
    ¬ WalkWith false (Valuation.entry ctxN 0 mem0 (frameH 1))
      ((naive.fn_0.b_3.label, hdr.obls, hdr) :: trip0) ∧
    covers naive.prog naive.fn_0 naive.fn_0.b_7.label 0 fin.obls fin = false := by
  decide +kernel

/-! ## A `br i1` into blocks with `phi`s, one edge at a time -/

/-- A `br i1` on `%3` from the entry block 0 into two blocks that start with a `phi`: block 1's
`%4 = phi i64 [7, %0]`, then `%6 = add nsw i64 %4, 1` and `ret void`; block 2's
`%5 = phi double [1.5, %0]` (a float constant, written as the bits of a `double`), then
`ret void`. -/
def edgeF : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "edge", params := [],
    group := none, names := #["entry", "a", "b", "c", "x", "y", "z"],
    blocks := #[⟨0, #[], .condBr (.loc 3) 1 2⟩,
      ⟨1, #[{ res := some 4, inst := .phi (.int 64) [(.int 7, 0)] },
        { res := some 6, inst := .bin .add { nsw := true } (.int 64) (.loc 4) (.int 1) }],
        .ret none⟩,
      ⟨2, #[⟨some 5, .phi (.fp .double) [(.float (.hex "" 0x3FF8000000000000), 0)], []⟩],
        .ret none⟩] }

/-- The program of `edgeF` alone. -/
def edgeP : Program := .ofFunc edgeF

/-- The context: `ctx0` with `edgeP`. -/
def ctxE : Ctx := { ctx0 with prog := edgeP }

/-- The frame at the entry block's position 0 with the condition `%3 = b`. -/
def frameE (b : Bool) : Frame :=
  ⟨edgeF, 0, 0, fun r => if r = 3 then some (.bits 1 (BitVec.ofBool b)) else none,
    fun _ => none, [], none⟩

/-- The entry block's summary with both edges' obligations (`summarize`). -/
sym_summary entryB := edgeP edgeF 0 0

/-- **Both edges**: the entry block's summary has one node, block 2's `phi` operand 1.5
(`SNode.flit`), and the obligations that `%3` is a word, that the constant 7 and node 0
evaluate, and that its effects (none) run; at `frameE true` under `ctxE` on `mem0` they hold
(node 0's value is `floatLit` of the literal, 1.5 as a `double`). -/
theorem entry_both :
    entryB.nodes = [.flit .double (.hex "" 0x3FF8000000000000)] ∧
    entryB.obls = [.bool (.reg 3), .ok (.int 64 7), .ok (.node 0), .mem []] ∧
    WalkWith false (Valuation.entry ctxE 0 mem0 (frameE true)) [(0, entryB.obls, entryB)] := by
  decide +kernel

/-- The entry block's summary for its edge into block 1 (`summarizeWith` with `SState.exitTo`,
evaluated): the exit `Exit.phi` on `%3`, with the obligations that `%3` is a word and that block
1's `phi` operand from block 0, the constant 7, evaluates; none about block 2's. -/
def entryTo : Summary :=
  (summarizeWith edgeP edgeF 0 0 fun σ tm => σ.exitTo edgeF 0 1 tm).getD default

/-- Block 1 from position 1, after its `phi`: the `add` and `ret void`. -/
sym_summary edgeA := edgeP edgeF 1 1

/-- The rest of the path through the edge into block 1: block 1. -/
def edgeT : List (Nat × List Cond × Summary) := [(1, edgeA.obls, edgeA)]

/-- The path checker with `phi`s accepts the path `0 → 1` from position 0: the entry block by
`coversTo` for its edge into block 1, block 1 from position 1. -/
theorem edge_covers :
    coversPathWith false edgeP edgeF 0 ((0, entryTo.obls, entryTo) :: edgeT) = true := by
  decide +kernel

/-- The path's premises hold at `frameE true` under `ctxE` on `mem0`: `%3` is the word 1, the
branch goes to block 1, and in block 1's entry valuation (`Valuation.into`) `%4 = 7`, so the
`add` evaluates. -/
theorem edge_walk :
    WalkWith false (Valuation.entry ctxE 0 mem0 (frameE true))
      ((0, entryTo.obls, entryTo) :: edgeT) := by
  decide +kernel

/-- **The run through the edge into block 1**: from `frameE true` the thread's steps run
the entry block and block 1 to its `ret`, and the next step returns (`Block.sound_retWith` with
`edge_covers` and `edge_walk`). For this program, context, memory and frame only. -/
theorem edge_run : ∃ fe me,
    Steps ctxE ⟨[frameE true], 0⟩ mem0 ⟨[fe], 0 + pathLen entryTo edgeT⟩ me ∧
    step ctxE ⟨[fe], 0 + pathLen entryTo edgeT⟩ me = .ok (.done me) := by
  obtain ⟨fe, me, hS, -, hst⟩ := Block.sound_retWith (c := ctxE) (t := ⟨[frameE true], 0⟩)
    (m := mem0) (f := frameE true) rfl edge_covers rfl rfl rfl rfl edge_walk rfl rfl
  rw [Valuation.allocsWith_nil _ edge_covers, List.nil_append] at hst
  exact ⟨fe, me, hS, hst⟩

/-- **The twins**: `coversTo` refuses the corrupted certificates `entryTo` without its first
obligation (that `%3` is a word) and `entryTo` with no obligations; the path checker refuses the
path `0 → 2` with `entryTo`, the certificate of the edge into block 1, and block 2's summary from
position 1 (`ret void` alone, `Kernels.vadd.b3`); and with `%3 = 0` the branch goes to block 2,
so the premises of the path `0 → 1` fail. -/
theorem edge_twins :
    coversTo edgeP edgeF 0 0 1 entryTo.obls.tail entryTo = false ∧
    coversTo edgeP edgeF 0 0 1 [] { entryTo with obls := [] } = false ∧
    coversPathWith false edgeP edgeF 0
      [(0, entryTo.obls, entryTo), (2, Kernels.vadd.b3.obls, Kernels.vadd.b3)] = false ∧
    ¬ WalkWith false (Valuation.entry ctxE 0 mem0 (frameE false))
      ((0, entryTo.obls, entryTo) :: edgeT) := by
  decide +kernel

/-! ## A `ret` to a caller frame -/

/-- A caller frame for `frameE true`: block 1 of `edgeF` at position 0 with `%4 = 7`; the
callee's `ret void` returns to its position 1, the `add`. -/
def callerE : Frame :=
  ⟨edgeF, 1, 0, fun r => if r = 4 then some (.bits 64 7) else none, fun _ => none, [], none⟩

/-- **Return to a caller**: from the thread `[frameE true, callerE]` under `ctxE` on
`mem0`, the steps run the callee's path `0 → 1` to its `ret`, return to `callerE` at position 1
and run block 1 from there to its `ret`, whose step returns (`Block.sound_back` with
`edge_covers`, `edge_walk` and `edgeA`'s certificate). For this program, context, memory and
frames only. -/
theorem edge_back : ∃ fe me, Steps ctxE ⟨[frameE true, callerE], 0⟩ mem0
      ⟨[fe], 0 + pathLen entryTo edgeT + 1 + edgeA.len⟩ me ∧
    step ctxE ⟨[fe], 0 + pathLen entryTo edgeT + 1 + edgeA.len⟩ me = .ok (.done me) := by
  obtain ⟨_, -, fe, me, hS, -, -, hal, -, -, -, -, r, hn, hst⟩ :=
    Block.sound_back (c := ctxE) (t := ⟨[frameE true, callerE], 0⟩) (m := mem0) (f := frameE true)
      (g := callerE) (rest := []) (dg := edgeA.obls) (Sg := edgeA) rfl edge_covers rfl rfl rfl
      rfl edge_walk rfl (by decide +kernel) fun me hm => by
        cases hm
        decide +kernel
  obtain ⟨fn', lbl', pc', regs', prods', al', de'⟩ := fe
  obtain rfl : al' = [] := hal
  exact ⟨_, me, hS, hst.trans (hn.symm.trans rfl)⟩

end MojoProofTest.SymPhi
