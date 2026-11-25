import MojoProofTest.SymLane
import MojoProof.Sym.Segment
import MojoProof.Sym.LoadAfter
import MojoProof.Sym.Payload

/-!
# Segments of the warp reductions

The summary of a segment of a block that ends at a collective call (`summarizeTo`,
MojoProof/Sym/Segment.lean; sound by `Seg.sound`) at the warp reductions of tests/corpus/gemv/
(fixtures `gemv` and `gevm`, MojoProofTest/SymLane.lean). A shape (`shape`) is the segment's
collective, its argument terms, its number of statements, and its numbers of nodes, registers,
memory effects and obligations.

* `gemv_segments`: gemv_kernel's block `%78` (gemv.fn_0.b_10, 21 statements, the `phi` at 0) is six
  segments. Five end at its `shfl.sync.bfly` calls at statements 2, 6, 10, 14 and 18 (from
  statements 1, 3, 7, 11 and 15; the offsets 16, 8, 4, 2, 1), with their shapes pinned; the
  last, from statement 19, is the block checker's summary to the conditional branch
  (`summarize`).
* `gevm_segments`: gevm_kernel's block `%59` (gevm.fn_0.b_5, 39 statements) is seven segments,
  each in the fragment, with their shapes pinned: to the barrier at 6 (from 1, with the `store`
  to the shared array), to the shuffles at 11, 15, 19, 23 and 27, and from 28 to the branch. The
  checker's refusal of the whole block (`refusal`) is at the barrier (from 1) and at the first
  shuffle (from 7).
* `gevm_after_barrier`: the table of the segment after the barrier (statements 7 to 10): the
  `trunc`, the pointer of the shared-memory global (`SNode.globalAt` at statement 8, operand 0),
  the `getelementptr` on it, the `load` and the `bitcast`; its one effect is the `load`.
* `gevm_shared`: under every valuation of gevm_kernel whose context gives the shared-memory
  global an address `p` (`Ctx.globals`), the global's nodes at statements 4 and 8 are the pointer
  `p` (`SNode.eval_globalAt`).
* `gemv_first_wait`: the first segment of `%78` on a thread: one step to the `.wait` of the
  shuffle, and the resumed thread's frame is at statement 3, where the second segment starts
  (`Seg.resume`). `gevm_after_barrier_wait`: the segment of `%59` after the barrier on a thread:
  four steps to the `.wait` of the first shuffle, and the resumed frame is at statement 12.
* `gevm_barrier_regs`: the segment of `%59` to the barrier on a thread: the resumed frame has at
  every register the value of the segment's summary, since the barrier has no result
  (`Seg.resume_regs`); `gevm_barrier_regs_twin`: the shuffle at 11 has one, the barrier none.
* `gevm_through`: `%59` from statement 1 with its collectives at 6, 11, 15, 19, 23 and 27
  (`summarizeSegs`): six segments of 5, 4, 3, 3, 3 and 3 statements, then 11 statements to the
  conditional branch; and on a thread at statement 1, whatever values the collectives deliver,
  the thread runs the block through them (`Seg.Through`, by `Seg.through`).

A `load` or `store` whose pointer operand is a global, with no `getelementptr`, at a layernorm
kernel of tests/corpus/layernorm/ (fixture `ln`):

* `ln_store`: block `%448` (ln.fn_0.b_38) is in the fragment: the `load` of the stack slot `%12`
  at statement 0, then the shared-memory global's pointer (`SNode.globalAt` at statement 1,
  operand 1, the `store`'s pointer) and the `store` of the loaded value on it; two statements to
  the branch. `ln_store_ends`: on a thread at its statement 0, if the summary's obligations hold,
  the block ends (`Ends`, by `Seg.through` with no collective). `ln_store_oblivious`: under the
  labelling with no payload register the summary is oblivious (`Summary.oblivious`): the global's
  pointer is skeleton (`SNode.pay`).
* `ln_load`: statement 1 of block `%453` (ln.fn_0.b_42, after its barrier), the `load` of the
  global, is the global's pointer (operand 0) and the `load` on it.
* `ln_shared`: the two global nodes are the address the context gives the global.

A `load` after a `store` (`SNode.loadAfter`, MojoProof/Sym/LoadAfter.lean), at the same block:

* `ln_after`: from statement 1, the checker takes the block through statement 9: the `store` of
  the loaded triple to the stack slot `%12` at 2, then the `load` and `store` of each of its three
  fields (`%175`, `%179` and `%169`) at 3 to 8 and the `load` of `%12` at 9, each `load` a node of
  the memory the effects before it make; it refuses the block at the `lifetime.end` call of
  statement 10. The fields' pointers are entry registers, of which the block's terms say nothing,
  so no node there is a stored value or the value without a `store`: the block is the open case.
* `ln_twin`: the twin of the block without statements 3 to 8: the `load` of `%12` of statement 9
  right after the `store` to `%12` of statement 2 is the stored triple's decoding
  (`SNode.eval_loadAfter_store`).
* `ln_apart`: the `load` of `%179` at statement 5, if its pointer and `%175`'s are apart, is the
  `load` without the `load` and `store` of `%175` at 3 and 4 (`SNode.eval_loadAfter_apart`,
  `SNode.eval_loadAfter_log`).
* `ln_reload`: the twin of the block whose statement 3 is the `load` of the global again: after the
  `store`, the global's pointer and the `load` on it from the memory the effects before it make.
* `ln_after_rel`: two runs of `ln_after`'s statements. Under the labelling whose one payload
  register is the triple loaded from the global (`lnLab`), the table passes (O3) (`SNode.payOk`
  on each payload node): the four loads after stores have skeleton pointers and effects with
  skeleton pointers. So for every payload blocks and two valuations related by `Valuation.Rel`
  whose skeleton loads read outside them, each node has related values in the two runs
  (`vals_rel`). The open twin: with the stack slot `%12` payload too (`lnLab12`), the table fails
  (O3), since the loads' effects store through a payload pointer.

Segments that end at a lifetime marker (`summarizeLife`, `Seg.lifetime`):

* `ln_life`: block `%453`'s statements 1 to 9 are the segment that ends at the `lifetime.end` on
  `%12` of statement 10, with `ln_after`'s effects; from 11, after the marker, the checker takes
  statements 11 to 15 and first refuses statement 16, the `rsqrt.approx` call.
* `ln_life_twin`: block `%151` (ln.fn_0.b_30) ends and starts the lifetimes of `%12` and `%11`
  (statements 6, 7, 9 and 10), each the end of a segment, the one from 8 with the `store` to
  `%12`; from 11 the checker takes statements to the shuffle at 13.
* `ln_zero`: from statement 11 of `%151`, the `store` of `zeroinitializer` to `%11`, the `load`
  of `%12` after it and the shuffle at 13 are a segment (`summarizeTo`), with the constant's node
  (`SNode.constAt`).
* `ln_after_store`: from statement 14 of `%151`, the `store` of the shuffled word, the two
  `getelementptr`s after it and the `load` through the second are a segment to the shuffle at 18;
  the open twin: from statement 27, a `getelementptr` with two indices that the checker takes,
  it refuses statement 31, the call of `llvm.maxnum.f32`.
* `ln_life_end`: on a thread at statement 1 of `%453`, the segment's steps to the `lifetime.end`
  and the step past it, on the memory with `%12`'s block's lifetime ended (`Seg.lifetime_ptr`).

A block through its lifetime markers (`summarizePieces`, `Piece.through`):

* `gemv_segs`: gemv_kernel's entry block `%6` (gemv.fn_0.b_0) from statement 3, after its
  `alloca`s, with its two shuffles and nine lifetime markers as stops (`gemvStops`), is eleven
  segments and the summary of statements 41 to 47 to the conditional branch; the segments hold
  the `extractelement`s, the `store`s of the shuffled words, the `insertvalue`s into `undef`,
  the `store` of the `[2 x ptr]`, the `getelementptr` with two indices, the `load`s after the
  `store`s and the `insertelement`s. On a thread at statement 3, the thread runs the block
  through the segments to the branch (`Piece.Through`).
* `gemv_segs_twin`: the open twin: the checker refuses statement 0, the first `alloca`, so there
  is no summary from 0; and with the marker at 28 missing from the stops, none from 3.
* `gemv_segs_alloca`: with the `alloca` flag, the whole of `%6` from statement 0: the same eleven
  segments, the first with the three `alloca`s' effects, and the summary to the branch; on a
  thread at statement 0, the thread runs the block through them (`Piece.Through`).
  `gemv_segs_alloca_mutant`: with the flag, the stops without the shuffle at 17 or the marker at
  28 give none, and without the flag the first segment has none.

Tests of six blocks of three kernels; `Seg.sound`, `Seg.resume`, `Seg.resume_regs`,
`Seg.through`, `Seg.lifetime` and `Piece.through` cover every program, `SNode.eval_globalAt` and
`SNode.eval_constAt` every valuation and statement, and the lemmas of
MojoProof/Sym/LoadAfter.lean every valuation, statements and effects.
-/

namespace MojoProofTest.SymSeg

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane

mojo_import "layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll" as ln

/-- The shape of a segment's summary. -/
structure Shape where
  /-- The shape from the collective, argument terms, number of statements and numbers of nodes,
  registers, memory effects and obligations. -/
  mk ::
  /-- The collective. -/
  call : Coll
  /-- The argument terms. -/
  args : List SVal
  /-- The number of statements. -/
  len : Nat
  /-- The number of nodes. -/
  nodes : Nat
  /-- The number of registers set. -/
  regs : Nat
  /-- The number of memory effects. -/
  effs : Nat
  /-- The number of obligations. -/
  obls : Nat
  deriving DecidableEq

/-- The shape of a segment's summary: its collective, its argument terms, its number of
statements, and its numbers of nodes, registers, memory effects and obligations. -/
def shape (S : SegSummary) : Shape :=
  ⟨S.call, S.args, S.len, S.nodes.length, S.regs.length, S.effs.length, S.obls.length⟩

/-- **gemv_kernel's warp reduction is six segments**: `summarizeTo` gives a summary of block
`%78` (`b_10`) from statement 1 to the shuffle at 2 (the argument the entry's node 0, the offset
16, six obligations), and from statements 3, 7, 11 and 15 to the shuffles at 6, 10, 14 and 18
(three statements each, the argument node 2, the offsets 8, 4, 2 and 1, eight obligations); no
segment has a memory effect. `summarize` gives the summary from statement 19 to the conditional
branch on `%41` (two statements, four obligations). -/
theorem gemv_segments :
    (summarizeTo gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 1 2).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 0, .int 32 16, .int 32 31], 1, 1, 1, 0, 6⟩ ∧
    (summarizeTo gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 3 6).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 2, .int 32 8, .int 32 31], 3, 3, 3, 0, 8⟩ ∧
    (summarizeTo gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 7 10).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 2, .int 32 4, .int 32 31], 3, 3, 3, 0, 8⟩ ∧
    (summarizeTo gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 11 14).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 2, .int 32 2, .int 32 31], 3, 3, 3, 0, 8⟩ ∧
    (summarizeTo gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 15 18).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 2, .int 32 1, .int 32 31], 3, 3, 3, 0, 8⟩ ∧
    (summarize gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 19).map
      (fun S => (S.exit, S.len, S.nodes.length, S.obls.length)) =
      some (.cond (.reg 41) 101 102, 2, 2, 4) := by
  decide +kernel

/-- **gevm_kernel's warp reduction is seven segments**: `summarizeTo` gives a summary of block
`%59` (`b_5`) from statement 1 to the barrier at 6 (five statements, five nodes, the `store` to
the shared array, the argument 0, seven obligations), from 7 to the shuffle at 11 (four
statements, five nodes, the `load` from the shared array, the argument node 4, the offset 16, ten
obligations), and from statements 12, 16, 20 and 24 to the shuffles at 15, 19, 23 and 27 (three
statements each, the offsets 8, 4, 2 and 1); `summarize` gives the summary from statement 28 to
the conditional branch (eleven statements, thirteen obligations). The first statement the
checker refuses from 1 is the barrier, and from 7 the first shuffle (`refusal`). -/
theorem gevm_segments :
    (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 6).map shape =
      some ⟨.barrier, [.int 32 0], 5, 5, 4, 1, 7⟩ ∧
    (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 7 11).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 4, .int 32 16, .int 32 31], 4, 5, 4, 1, 10⟩ ∧
    (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 12 15).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 2, .int 32 8, .int 32 31], 3, 3, 3, 0, 8⟩ ∧
    (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 16 19).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 2, .int 32 4, .int 32 31], 3, 3, 3, 0, 8⟩ ∧
    (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 20 23).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 2, .int 32 2, .int 32 31], 3, 3, 3, 0, 8⟩ ∧
    (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 24 27).map shape =
      some ⟨.shfl .bfly, [.int 32 (-1), .node 2, .int 32 1, .int 32 31], 3, 3, 3, 0, 8⟩ ∧
    (summarize gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 28).map
      (fun S => (S.exit, S.len, S.nodes.length, S.obls.length)) =
      some (.cond (.node 10) 97 98, 11, 11, 13) ∧
    refusal gevm.prog gevm.fn_0 gevm.fn_0.b_5 1 = some 6 ∧
    refusal gevm.prog gevm.fn_0 gevm.fn_0.b_5 7 = some 11 := by
  decide +kernel

/-- **The segment after gevm_kernel's barrier**: the summary `summarizeTo` gives of block `%59`
(`b_5`) from statement 7 to the shuffle at 11 has the table: the `trunc` of the entry register
`%10`, the pointer of the global that operand 0 of statement 8 names (the shared array), the
`getelementptr` at 8 on that node and the `trunc`, the `load` at 9 through it and the `bitcast`
at 10 of the loaded value (three steps after the segment's start); and the one effect, the
`load`'s. -/
theorem gevm_after_barrier :
    (summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 7 11).map (fun S => (S.nodes, S.effs)) =
      some ([.cast .trunc 32 (.reg 10), .globalAt gevm.fn_0.b_5.label 8 0,
        .gep gevm.fn_0.b_5.label 8 (.node 1) (.node 0), .load gevm.fn_0.b_5.label 9 (.node 2),
        .castAt gevm.fn_0.b_5.label 10 3 (.node 3)], [.load gevm.fn_0.b_5.label 9 (.node 2)]) := by
  decide +kernel

/-- **The shared array's pointer**: for every valuation `V` of gevm_kernel (`V.fn = gevm.fn_0`),
node values `vs` and address `p` that `V`'s context gives the shared-memory global
`gevm_kernel_float32_float32_float32_1024_1308aaae._global_alloc_0._gpu_shared_mem`
(`Ctx.globals`, which `Grid.start` sets for each thread block), the global's nodes at statements
4 and 8 of `%59` (`b_5`; operand 0, the `getelementptr`s' base) are the pointer `p`
(`SNode.eval_globalAt`). -/
theorem gevm_shared {V : Valuation} (hf : V.fn = gevm.fn_0) (vs : List (Except Fault Val))
    {p : Ptr} (hg : V.ctx.globals
      "gevm_kernel_float32_float32_float32_1024_1308aaae._global_alloc_0._gpu_shared_mem" =
      some p) :
    (SNode.globalAt gevm.fn_0.b_5.label 4 0).eval V vs = .ok (.ptr p) ∧
      (SNode.globalAt gevm.fn_0.b_5.label 8 0).eval V vs = .ok (.ptr p) :=
  ⟨SNode.eval_globalAt (by rw [Valuation.stmt, hf]; rfl) (by rfl) hg,
    SNode.eval_globalAt (by rw [Valuation.stmt, hf]; rfl) (by rfl) hg⟩

/-- **The first segment of gemv_kernel's `%78` on a thread**: for every summary `S` that
`summarizeTo` gives for statements 1 to 2 of `b_10`, every context of gemv_kernel's program and
thread whose innermost frame `f` (above frames `rest`) runs `gemv_kernel` at `b_10`, statement 1,
with memory `m`: if `S`'s obligations hold under `f`'s entry valuation, the thread's steps reach,
one step later, a frame whose step is the `.wait` of `shfl.sync.bfly`, and for every value of
the call the resumed thread's frame is at statement 3 of `b_10`, where the second segment
starts. -/
theorem gemv_first_wait {S : SegSummary}
    (hS : summarizeTo gemv.prog gemv.fn_0 gemv.fn_0.b_10.label 1 2 = some S) {c : Ctx}
    (hP : c.prog = gemv.prog) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = gemv.fn_0) (hl : f.label = gemv.fn_0.b_10.label)
    (hp : f.pc = 1)
    (hds : ∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    ∃ fe me ws fd, Steps c t m ⟨fe :: rest, t.k + 1⟩ me ∧
      step c ⟨fe :: rest, t.k + 1⟩ me = .ok (.wait (.shfl .bfly) ws fd) ∧
      ∀ v, ∃ fr, Thread.resume ⟨fe :: rest, t.k + 1⟩ v = ⟨fr :: rest, t.k + 1 + 1⟩ ∧
        fr.fn = gemv.fn_0 ∧ fr.label = gemv.fn_0.b_10.label ∧ fr.pc = 3 :=
  Seg.resume (cl := .shfl .bfly) (n := 1) hS (by decide +kernel) hP ht hfn hl hp hds

/-- **The segment after gevm_kernel's barrier on a thread**: for every summary `S` that
`summarizeTo` gives for statements 7 to 11 of `%59` (`b_5`), every context of gevm_kernel's
program and thread whose innermost frame `f` (above frames `rest`) runs `gevm_kernel` at `b_5`,
statement 7 (where the thread resumes from the barrier), with memory `m`: if `S`'s obligations
hold under `f`'s entry valuation, the thread's steps reach, four steps later, a frame whose step
is the `.wait` of `shfl.sync.bfly`, and for every value of the call the resumed thread's frame is
at statement 12 of `b_5`, where the next segment starts. -/
theorem gevm_after_barrier_wait {S : SegSummary}
    (hS : summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 7 11 = some S) {c : Ctx}
    (hP : c.prog = gevm.prog) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = gevm.fn_0) (hl : f.label = gevm.fn_0.b_5.label)
    (hp : f.pc = 7)
    (hds : ∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    ∃ fe me ws fd, Steps c t m ⟨fe :: rest, t.k + 4⟩ me ∧
      step c ⟨fe :: rest, t.k + 4⟩ me = .ok (.wait (.shfl .bfly) ws fd) ∧
      ∀ v, ∃ fr, Thread.resume ⟨fe :: rest, t.k + 4⟩ v = ⟨fr :: rest, t.k + 4 + 1⟩ ∧
        fr.fn = gevm.fn_0 ∧ fr.label = gevm.fn_0.b_5.label ∧ fr.pc = 12 :=
  Seg.resume (cl := .shfl .bfly) (n := 4) hS (by decide +kernel) hP ht hfn hl hp hds

/-- **The registers after gevm_kernel's barrier**: for every summary `S` that `summarizeTo` gives
for statements 1 to 6 of `%59` (`b_5`), every context of gevm_kernel's program and thread whose
innermost frame `f` (above frames `rest`) runs `gevm_kernel` at `b_5`, statement 1, with memory
`m`: if `S`'s obligations hold under `f`'s entry valuation, the thread's steps reach a frame `fe`,
and for every value of the barrier the resumed thread's frame has at every register the value
`S`'s registers give it (`regVal`): the barrier has no result (`Seg.resume_regs`). -/
theorem gevm_barrier_regs {S : SegSummary}
    (hS : summarizeTo gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 6 = some S) {c : Ctx}
    (hP : c.prog = gevm.prog) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = gevm.fn_0) (hl : f.label = gevm.fn_0.b_5.label)
    (hp : f.pc = 1)
    (hds : ∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + S.len⟩ me ∧
      ∀ v, ∃ fr, Thread.resume ⟨fe :: rest, t.k + S.len⟩ v = ⟨fr :: rest, t.k + S.len + 1⟩ ∧
        ∀ r, fr.regs r = regVal (Valuation.entry c t.k m f)
          (vals (Valuation.entry c t.k m f) S.nodes) S.regs r := by
  obtain ⟨fe, me, hSt, h⟩ := Seg.resume_regs hS hP ht hfn hl hp hds
  have hn : ((gevm.fn_0.blocks.find? (·.label == gevm.fn_0.b_5.label)).bind
      fun b => b.stmts[6]?.bind (·.res)) = none := by
    decide +kernel
  refine ⟨fe, me, hSt, fun v => ?_⟩
  obtain ⟨fr, hr, hfr⟩ := h v
  exact ⟨fr, hr, fun r => hfr r (by rw [hn]; simp)⟩

/-- **The open twin, a shuffle's result**: the shuffle at statement 11 of `%59` (`b_5`) has a
result register, which the call's value sets, so `Seg.resume_regs` gives no value of `S` there;
the barrier at 6 has none. -/
theorem gevm_barrier_regs_twin :
    ((gevm.fn_0.blocks.find? (·.label == gevm.fn_0.b_5.label)).bind
      fun b => b.stmts[11]?.bind (·.res)).isSome ∧
    ((gevm.fn_0.blocks.find? (·.label == gevm.fn_0.b_5.label)).bind
      fun b => b.stmts[6]?.bind (·.res)).isNone := by
  decide +kernel

/-- **gevm_kernel's `%59` on one thread, through its collectives**: `summarizeSegs` gives, from
statement 1 of `b_5` with the collective calls at 6, 11, 15, 19, 23 and 27, six segments of 5, 4,
3, 3, 3 and 3 statements and the rest, 11 statements to the conditional branch on node 10; and
for every context of gevm_kernel's program, values and memories `w` the barrier and the five
shuffles deliver, and thread whose innermost frame `f` (above frames `rest`) runs `gevm_kernel` at
`b_5`, statement 1, with memory `m`, the thread runs the block through them (`Seg.Through`, by
`Seg.through`), each segment's obligations a premise at its start frame. A test of
`Seg.through` at one block, at symbolic values. -/
theorem gevm_through :
    (summarizeSegs gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 [6, 11, 15, 19, 23, 27]).map
        (fun x => (x.1.map (·.len), x.2.len, x.2.exit)) =
      some ([5, 4, 3, 3, 3, 3], 11, .cond (.node 10) 97 98) ∧
    ∀ {c : Ctx}, c.prog = gevm.prog → ∀ (w : Nat → Option Val × Mem) {t : Thread} {m : Mem}
      {f : Frame} {rest : List Frame}, t.frames = f :: rest → f.fn = gevm.fn_0 →
      f.label = gevm.fn_0.b_5.label → f.pc = 1 →
      ∃ Ss L, summarizeSegs gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1 [6, 11, 15, 19, 23, 27] =
        some (Ss, L) ∧ Seg.Through c gevm.fn_0.b_5.label rest L Ss w t m f := by
  have h : (summarizeSegs gevm.prog gevm.fn_0 gevm.fn_0.b_5.label 1
      [6, 11, 15, 19, 23, 27]).isSome = true := by
    decide +kernel
  obtain ⟨⟨Ss, L⟩, hx⟩ := Option.isSome_iff_exists.1 h
  refine ⟨by decide +kernel, ?_⟩
  intro c hP w t m f rest ht hfn hl hp
  exact ⟨Ss, L, hx, Seg.through hP hx w ht hfn hl hp⟩

/-- **A `store` on a global**: the summary of layernorm's block `%448` (`b_38`) from statement 0:
after the `load` of the stack slot (node 0), the pointer of the shared-memory global, operand 1 of
the `store` at statement 1 (`SNode.globalAt`), and the `store` of node 0 on it; two statements to
the branch. -/
theorem ln_store :
    (summarize ln.prog ln.fn_0 ln.fn_0.b_38.label 0).map
        (fun S => (S.nodes.drop 1, S.effs.drop 1, S.len)) =
      some ([.globalAt ln.fn_0.b_38.label 1 1],
        [.store ln.fn_0.b_38.label 1 (.node 0) (.node 1)], 2) := by
  decide +kernel

/-- **The block with the `store` on a global on a thread**: the summary `S` of layernorm's block
`%448` (`b_38`) from statement 0 exists, and for every context of its program and thread whose
innermost frame `f` (above frames `rest`) runs the kernel at that block, statement 0, with memory
`m`: if `S`'s obligations hold under `f`'s entry valuation, the block ends (`Ends`; `Seg.through`
with no collective). -/
theorem ln_store_ends :
    ∃ S, summarize ln.prog ln.fn_0 ln.fn_0.b_38.label 0 = some S ∧
      ∀ {c : Ctx}, c.prog = ln.prog → ∀ {t : Thread} {m : Mem} {f : Frame} {rest : List Frame},
        t.frames = f :: rest → f.fn = ln.fn_0 → f.label = ln.fn_0.b_38.label → f.pc = 0 →
        (∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
          (vals (Valuation.entry c t.k m f) S.nodes)) →
        Ends c t m f rest (Valuation.entry c t.k m f, ln.fn_0.b_38.label, S) := by
  have h : (summarize ln.prog ln.fn_0 ln.fn_0.b_38.label 0).isSome = true := by
    decide +kernel
  obtain ⟨S, hS⟩ := Option.isSome_iff_exists.1 h
  refine ⟨S, hS, ?_⟩
  intro c hP t m f rest ht hfn hl hp hds
  have hx : summarizeSegs ln.prog ln.fn_0 ln.fn_0.b_38.label 0 [] = some ([], S) := by
    simp [summarizeSegs, hS]
  exact Seg.through hP hx (fun _ => (none, m)) ht hfn hl hp hds

/-- **The `store` on a global is oblivious**: under the labelling with no payload register, the
summary of layernorm's block `%448` (`b_38`) from statement 0 is oblivious (`Summary.oblivious`):
the pointer of its `store`, the global's pointer node, is skeleton (`SNode.pay`), so in two runs
with one table of globals it has one value (`Summary.oblivious_skel`). -/
theorem ln_store_oblivious :
    (summarize ln.prog ln.fn_0 ln.fn_0.b_38.label 0).map
        (Summary.oblivious ⟨fun _ _ => false, fun _ => false⟩ ln.fn_0) = some true := by
  decide +kernel

/-- **A `load` on a global**: statement 1 of layernorm's block `%453` (`b_42`), the `load` of the
shared-memory global after the barrier, from a state with no node: the global's pointer (operand 0,
`SNode.globalAt`), then the `load` on it, whose effect is the one memory effect. -/
theorem ln_load :
    (SState.run false ln.prog ln.fn_0.b_42.label 1 ((ln.fn_0.b_42.stmts.toList.drop 1).take 1) 0
        ⟨[], [], [], [], false, false⟩).map (fun σ => (σ.nodes, σ.effs)) =
      some ([.globalAt ln.fn_0.b_42.label 1 0, .load ln.fn_0.b_42.label 1 (.node 0)],
        [.load ln.fn_0.b_42.label 1 (.node 0)]) := by
  decide +kernel

/-- The memory effects of layernorm's block `%453` (`b_42`) from statement 1 to 8: the `load` of
the shared-memory global (node 0), the `store` of the loaded triple (node 1) to the stack slot
`%12` (entry register 12), and the `load` and `store` of each field through `%175`, `%179` and
`%169` (entry registers 177, 181 and 171), each `store` of the node its `load` makes. -/
def lnEffs : List SEff :=
  [.load ln.fn_0.b_42.label 1 (.node 0), .store ln.fn_0.b_42.label 2 (.node 1) (.reg 12),
    .load ln.fn_0.b_42.label 3 (.reg 177), .store ln.fn_0.b_42.label 4 (.node 2) (.reg 177),
    .load ln.fn_0.b_42.label 5 (.reg 181), .store ln.fn_0.b_42.label 6 (.node 3) (.reg 181),
    .load ln.fn_0.b_42.label 7 (.reg 171), .store ln.fn_0.b_42.label 8 (.node 4) (.reg 171)]

/-- **Loads after a store**: from statement 1 of layernorm's block `%453` (`b_42`) and a state
with no node, the checker takes statements 1 to 9: after the global's nodes, the `load`s of
statements 3, 5 and 7 (through `%175`, `%179` and `%169`) and 9 (through `%12`), each from the
memory the effects before it make (`SNode.loadAfter` with the first 2, 4, 6 and 8 of `lnEffs`);
the effects are `lnEffs` and the last `load`'s. The first statement it refuses from 1 is the
`lifetime.end` call of statement 10 (`refusal`). -/
theorem ln_after :
    (SState.run false ln.prog ln.fn_0.b_42.label 1 ((ln.fn_0.b_42.stmts.toList.drop 1).take 9) 0
        ⟨[], [], [], [], false, false⟩).map (fun σ => (σ.nodes.drop 2, σ.effs)) =
      some ([.loadAfter ln.fn_0.b_42.label 3 (.reg 177) (lnEffs.take 2),
        .loadAfter ln.fn_0.b_42.label 5 (.reg 181) (lnEffs.take 4),
        .loadAfter ln.fn_0.b_42.label 7 (.reg 171) (lnEffs.take 6),
        .loadAfter ln.fn_0.b_42.label 9 (.reg 12) lnEffs],
        lnEffs ++ [.load ln.fn_0.b_42.label 9 (.reg 12)]) ∧
    refusal ln.prog ln.fn_0 ln.fn_0.b_42 1 = some 10 := by
  decide +kernel

/-- **A `load` right after a `store` at the same pointer**: the twin of layernorm's block `%453`
(`b_42`) without statements 3 to 8. For every valuation `V` of the kernel (`V.fn = ln.fn_0`),
node values `vs`, memory `m` and values `v` and `v'`: if the first two of `lnEffs` (the `load` of
the global and the `store` of node 1 to `%12`) run to `m`, node 1 has value `v`, and the bytes
`bs` of `v` as the triple `{float, float, float}` decode to `v'`, then the `load` of `%12` of
statement 9 after them is `v'` (`SNode.eval_loadAfter_store`; the two statements' types, address
space and alignment agree, and the `load` is not `noundef`). -/
theorem ln_twin {V : Valuation} (hf : V.fn = ln.fn_0) {vs : List (Except Fault Val)} {m : Mem}
    {v v' : Val} {bs : List MemByte} (hr : SEff.run V vs (lnEffs.take 2) = .ok m)
    (hx : (SVal.node 1).eval V vs = .ok v)
    (hbs : V.ctx.prog.layout.encode (.struct [.fp .float, .fp .float, .fp .float]) v = some bs)
    (hd : V.ctx.prog.layout.decode (.struct [.fp .float, .fp .float, .fp .float]) bs = some v') :
    (SNode.loadAfter ln.fn_0.b_42.label 9 (.reg 12) (lnEffs.take 2)).eval V vs = .ok v' :=
  SNode.eval_loadAfter_store (es := lnEffs.take 1) (by rw [Valuation.stmt, hf]; rfl)
    (by rw [Valuation.stmt, hf]; rfl) (by rfl) hr rfl hx hbs hd (by rfl)

/-- **A `load` after a `store` apart from it**: for every valuation `V` of layernorm's kernel
(`V.fn = ln.fn_0`), node values `vs`, memory `m`, value `v` and pointers `r` and `r'` of `%179`
and `%175` (entry registers 181 and 177) whose bytes as floats are apart (other blocks, or 4 bytes
from `r.off` before or after the 4 from `r'.off`): if the first four of `lnEffs` run and the
`load` of statement 5 of `%453` (`b_42`) through `%179` after the first two (the twin without
statements 3 and 4) is `v`, then so is the node of the checker after the four
(`SNode.eval_loadAfter_apart` for the `store` of 4, `SNode.eval_loadAfter_log` for the `load` of
3). -/
theorem ln_apart {V : Valuation} (hf : V.fn = ln.fn_0) {vs : List (Except Fault Val)} {m : Mem}
    {v : Val} {r r' : Ptr} (hr : SEff.run V vs (lnEffs.take 4) = .ok m)
    (hp : (SVal.reg 181).eval V vs = .ok (.ptr r)) (hy : (SVal.reg 177).eval V vs = .ok (.ptr r'))
    (hap : r.block ≠ r'.block ∨ r.off.toNat + 4 ≤ r'.off.toNat ∨ r'.off.toNat + 4 ≤ r.off.toNat)
    (hv : (SNode.loadAfter ln.fn_0.b_42.label 5 (.reg 181) (lnEffs.take 2)).eval V vs = .ok v) :
    (SNode.loadAfter ln.fn_0.b_42.label 5 (.reg 181) (lnEffs.take 4)).eval V vs = .ok v := by
  obtain ⟨m₀, hm₀, -⟩ := SEff.run_snoc (es := lnEffs.take 3) hr
  refine SNode.eval_loadAfter_apart (es := lnEffs.take 3) (by rw [Valuation.stmt, hf]; rfl)
    (by rw [Valuation.stmt, hf]; rfl) hr hp hy ?_
    ((SNode.eval_loadAfter_log (es := lnEffs.take 2) hm₀).trans hv)
  have h4 : V.ctx.prog.layout.stored (.fp .float) = 4 := by
    simp only [Layout.stored, Layout.storeSize, Layout.scalarBits]
    rfl
  rw [h4]
  exact hap

/-- **A `load` on a global after a `store`**: the twin of layernorm's block `%453` (`b_42`) whose
statement 3 is its statement 1, the `load` of the shared-memory global, again: from statement 1,
after the `store` of statement 2, the checker takes it as the global's pointer (`SNode.globalAt`,
operand 0) and the `load` on that node from the memory the two effects before it make
(`SNode.loadAfter`), with the `load`'s effect. -/
theorem ln_reload :
    (SState.run false ln.prog ln.fn_0.b_42.label 1
        ((ln.fn_0.b_42.stmts.toList.drop 1).take 2 ++ (ln.fn_0.b_42.stmts.toList.drop 1).take 1) 0
        ⟨[], [], [], [], false, false⟩).map (fun σ => (σ.nodes.drop 2, σ.effs.drop 2)) =
      some ([.globalAt ln.fn_0.b_42.label 3 0,
        .loadAfter ln.fn_0.b_42.label 3 (.node 2) (lnEffs.take 2)],
        [.load ln.fn_0.b_42.label 3 (.node 2)]) := by
  decide +kernel

/-- The labelling of layernorm's kernel whose one payload register is the result of statement 1
of block `%453` (`b_42`), the triple loaded from the shared-memory global. -/
def lnLab : Labels :=
  ⟨fun _ r => resReg ln.fn_0 ln.fn_0.b_42.label 1 == some r, fun _ => false⟩

/-- `lnLab` with the stack slot `%12` (entry register 12) payload too. -/
def lnLab12 : Labels :=
  ⟨fun _ r => r == 12 || resReg ln.fn_0 ln.fn_0.b_42.label 1 == some r, fun _ => false⟩

/-- **Loads after a store in two runs**: the state `σ` the checker gives from statement 1 of
layernorm's block `%453` (`b_42`) through statement 9 (`ln_after`) has a table that passes (O3)
under `lnLab` (`Summary.payOk` on it): the `load` of the global reads a data type through a
skeleton pointer, and the four `load`s after `store`s (`SNode.loadAfter`) have skeleton pointers
and carry effects with skeleton pointers. So for every payload blocks `pay` and valuations of the
kernel related by `Valuation.Rel lnLab pay` whose skeleton loads read outside `pay` under the
first (`Valuation.LoadsOk`), each node of the table has related values under both (`Val.Skel` at
a payload role, equal at a skeleton one; `vals_rel`). The open twin: under `lnLab12`, with `%12`
payload, the table fails (O3). -/
theorem ln_after_rel : ∃ σ, SState.run false ln.prog ln.fn_0.b_42.label 1
      ((ln.fn_0.b_42.stmts.toList.drop 1).take 9) 0 ⟨[], [], [], [], false, false⟩ = some σ ∧
    (∀ {pay : Nat → Prop} {V₁ V₂ : Valuation}, V₁.Rel lnLab pay V₂ → V₁.fn = ln.fn_0 →
      V₁.LoadsOk lnLab pay σ.nodes →
      ∀ j, Option.Rel (Except.Rel (Labels.Rel ((roles lnLab ln.fn_0 σ.nodes).getD j false)
        Val.Skel)) (vals V₁ σ.nodes)[j]? (vals V₂ σ.nodes)[j]?) ∧
    Summary.payOk lnLab12 ln.fn_0 ⟨σ.nodes, [], [], [], .ret, 0⟩ = false := by
  have ho : (SState.run false ln.prog ln.fn_0.b_42.label 1
      ((ln.fn_0.b_42.stmts.toList.drop 1).take 9) 0 ⟨[], [], [], [], false, false⟩).map (fun σ =>
        (Summary.payOk lnLab ln.fn_0 ⟨σ.nodes, [], [], [], .ret, 0⟩,
          Summary.payOk lnLab12 ln.fn_0 ⟨σ.nodes, [], [], [], .ret, 0⟩)) = some (true, false) := by
    decide +kernel
  obtain ⟨σ, hσ, he⟩ := Option.map_eq_some_iff.1 ho
  simp only [Prod.mk.injEq] at he
  refine ⟨σ, hσ, fun {pay V₁ V₂} h hf hl => ?_, he.2⟩
  have := vals_rel h hl (Summary.payOk_getElem? (S := ⟨σ.nodes, [], [], [], .ret, 0⟩)
    (by rw [hf]; exact he.1))
  rw [hf] at this
  exact this

/-- **The shared array's pointer at layernorm**: for every valuation `V` of the layernorm kernel
(`V.fn = ln.fn_0`), node values `vs` and address `p` that `V`'s context gives the shared-memory
global (`Ctx.globals`), the global's nodes of the `store` (block `%448`, statement 1, operand 1) and
of the `load` (block `%453`, statement 1, operand 0) are the pointer `p`
(`SNode.eval_globalAt`). -/
theorem ln_shared {V : Valuation} (hf : V.fn = ln.fn_0) (vs : List (Except Fault Val)) {p : Ptr}
    (hg : V.ctx.globals
      "rowwise_block_t0_r1_ax0_w1_bs128_847b1b53._global_alloc_0._gpu_shared_mem" = some p) :
    (SNode.globalAt ln.fn_0.b_38.label 1 1).eval V vs = .ok (.ptr p) ∧
      (SNode.globalAt ln.fn_0.b_42.label 1 0).eval V vs = .ok (.ptr p) :=
  ⟨SNode.eval_globalAt (by rw [Valuation.stmt, hf]; rfl) (by rfl) hg,
    SNode.eval_globalAt (by rw [Valuation.stmt, hf]; rfl) (by rfl) hg⟩

/-- **A segment that ends at a lifetime marker**: from statement 1 of layernorm's block `%453`
(`b_42`), the statements before the `lifetime.end` call on `%12` (entry register 12) of
statement 10 are a segment (`summarizeLife`) with the effects of `ln_after`, ending at that
marker; and from statement 11, after it, the checker takes statements 11 to 15 (three
`extractvalue`s, an `fdiv` and an `fadd contract`) and first refuses statement 16, the
`rsqrt.approx` call (`refusal`). -/
theorem ln_life :
    (summarizeLife ln.prog ln.fn_0 ln.fn_0.b_42.label 1 10).map (fun r => (r.1.effs, r.2)) =
      some (lnEffs ++ [.load ln.fn_0.b_42.label 9 (.reg 12)], false, .reg 12) ∧
    refusal ln.prog ln.fn_0 ln.fn_0.b_42 11 = some 16 := by
  decide +kernel

/-- **Lifetime markers that end and start**: layernorm's block `%151` (`b_30`) ends and starts
the lifetimes of `%12` and `%11` (entry registers 12 and 11) before it stores to each. The segments
from statement 6 to the `lifetime.end` on `%12` there, from 7 to the `lifetime.start` on `%12`
there, from 8 (the `store` to `%12`) to the `lifetime.end` on `%11` of 9, and from 10 to the
`lifetime.start` on `%11` there are `summarizeLife`'s; the first statement the checker refuses
from 11 is 13, the shuffle (`refusal`), where `ln_zero`'s segment ends. -/
theorem ln_life_twin :
    (summarizeLife ln.prog ln.fn_0 ln.fn_0.b_30.label 6 6).map (·.2) = some (false, .reg 12) ∧
    (summarizeLife ln.prog ln.fn_0 ln.fn_0.b_30.label 7 7).map (·.2) = some (true, .reg 12) ∧
    (summarizeLife ln.prog ln.fn_0 ln.fn_0.b_30.label 8 9).map (·.2) = some (false, .reg 11) ∧
    (summarizeLife ln.prog ln.fn_0 ln.fn_0.b_30.label 10 10).map (·.2) = some (true, .reg 11) ∧
    refusal ln.prog ln.fn_0 ln.fn_0.b_30 11 = some 13 := by
  decide +kernel

/-- **A `store` of `zeroinitializer`**: from statement 11 of layernorm's block `%151` (`b_30`),
the `store` of `zeroinitializer` to `%11` (entry register 11), the `load` of `%12` (entry register
12) after it and the shuffle at 13 of the loaded word are a segment (`summarizeTo`). Its table has
the block's float constant, the node of the stored constant (`SNode.constAt`) and the node of the
load from the memory the `store`'s effect makes (`SNode.loadAfter`); its effects are the `store`
of the constant's node and the `load`. Its open twin is `ln_after_store`'s. -/
theorem ln_zero :
    (summarizeTo ln.prog ln.fn_0 ln.fn_0.b_30.label 11 13).map (fun S => (S.nodes, S.effs)) =
      some ([.flit .float (.dec false "1" "000000" 0), .constAt ln.fn_0.b_30.label 11 0,
          .loadAfter ln.fn_0.b_30.label 12 (.reg 12)
            [.store ln.fn_0.b_30.label 11 (.node 1) (.reg 11)]],
        [.store ln.fn_0.b_30.label 11 (.node 1) (.reg 11),
          .load ln.fn_0.b_30.label 12 (.reg 12)]) := by
  decide +kernel

/-- **Addresses after a `store`**: from statement 14 of layernorm's block `%151` (`b_30`), the
`store` of the shuffled word (entry register 161) to `%11` (entry register 11), the
`getelementptr`s at 15 and 16 on `%11` and `%12` (entry register 12) after it, and the `load` at
17 through the second, from the memory the `store`'s effect makes (`SNode.loadAfter`), are a
segment to the shuffle at 18 (`summarizeTo`): a `getelementptr` reads only the blocks' addresses
and sizes, which a `store` keeps (`SEff.run_shape`). The open twin: from statement 27, a
`getelementptr` with two indices (`SNode.gepN`), the checker refuses statement 31, the call of
`llvm.maxnum.f32` (`refusal`). -/
theorem ln_after_store :
    (summarizeTo ln.prog ln.fn_0 ln.fn_0.b_30.label 14 18).map (fun S => (S.nodes, S.effs)) =
      some ([.flit .float (.dec false "1" "000000" 0),
          .gep ln.fn_0.b_30.label 15 (.reg 11) (.int 32 1),
          .gep ln.fn_0.b_30.label 16 (.reg 12) (.int 32 1),
          .loadAfter ln.fn_0.b_30.label 17 (.node 2)
            [.store ln.fn_0.b_30.label 14 (.reg 161) (.reg 11)]],
        [.store ln.fn_0.b_30.label 14 (.reg 161) (.reg 11),
          .load ln.fn_0.b_30.label 17 (.node 2)]) ∧
    refusal ln.prog ln.fn_0 ln.fn_0.b_30 27 = some 31 := by
  decide +kernel

/-- **The step at `%453`'s `lifetime.end`**: the segment of `ln_life` has a state `σ`, and for
every context of layernorm's program and thread whose innermost frame runs the kernel at
statement 1 of `%453` (`b_42`), with memory `m`: if the segment's obligations hold under the entry
valuation, the thread's steps reach statement 10, and when `%12` (entry register 12) is a pointer
`q` into a block of the memory `me` there that the thread owns, the step at the `lifetime.end`
moves to statement 11 on `me` with `q`'s block's lifetime ended (`Seg.lifetime_ptr`). -/
theorem ln_life_end : ∃ σ, summarizeLife ln.prog ln.fn_0 ln.fn_0.b_42.label 1 10 =
      some (σ, false, .reg 12) ∧
    ∀ {c : Ctx}, c.prog = ln.prog → ∀ {t : Thread} {m : Mem} {f : Frame} {rest : List Frame},
      t.frames = f :: rest → f.fn = ln.fn_0 → f.label = ln.fn_0.b_42.label → f.pc = 1 →
      (∀ d ∈ Cond.ok (.reg 12) :: .mem σ.effs :: σ.obls, d.Holds (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) σ.nodes)) →
      ∃ fe me w, Steps c t m ⟨fe :: rest, t.k + (10 - 1)⟩ me ∧ fe.pc = 10 ∧
        (SVal.reg 12).eval (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) σ.nodes) =
          .ok w ∧
        ∀ q, w = .ptr q → ((me.block q).any fun b => b.owner == .thread c.who.thread) = true →
          ∃ fr, step c ⟨fe :: rest, t.k + (10 - 1)⟩ me =
              .ok (.next ⟨fr :: rest, t.k + (10 - 1) + 1⟩ (me.setLive q.block false)) ∧
            fr.pc = 11 := by
  obtain ⟨⟨σ, s, x⟩, hS, he⟩ := Option.map_eq_some_iff.1 ln_life.1
  simp only [Prod.mk.injEq] at he
  obtain ⟨-, rfl, rfl⟩ := he
  refine ⟨σ, hS, fun hP _ _ _ _ ht hfn hl hp hds => ?_⟩
  obtain ⟨fe, me, w, hSt, -, -, hpc, -, hw, hq, -⟩ := Seg.lifetime_ptr hS hP ht hfn hl hp hds
  exact ⟨fe, me, w, hSt, hpc, hw, fun q h ho => (hq q h ho).imp fun _ ⟨hs, _, _, h3⟩ => ⟨hs, h3⟩⟩

/-- The flag, pointer term and number of statements of a lifetime marker's segment; `none` for a
collective's. -/
def lifeShape : Piece → Option (Bool × SVal × Nat)
  | .life _ s x n => some (s, x, n)
  | .coll _ => none

/-- The stops of gemv_kernel's entry block `%6` (`gemv.fn_0.b_0`) from statement 3: the shuffles
at 17 and 18 and the lifetime markers on `%9`, `%8` and `%7` at 19, 20, 22, 23, 25, 28, 38, 39
and 40. -/
def gemvStops : List Nat := [17, 18, 19, 20, 22, 23, 25, 28, 38, 39, 40]

/-- **gemv_kernel's `%6` after its `alloca`s**: `summarizePieces` gives, from statement 3 of the
entry block `%6` (`gemv.fn_0.b_0`) with the stops `gemvStops`, eleven segments, then the summary
of statements 41 to 47 (the `bitcast`, `getelementptr`, `mul`, `laneid` call, `sext` and two
`icmp`s) to the conditional branch on node 6. The segments: to the shuffles at 17 and 18, the
first with the two `extractelement`s at 15 and 16 of the vector the `bitcast` at 14 makes; the
`lifetime.end` and `lifetime.start` on `%9` (entry register 9) at 19 and 20; the `store` to `%9`
and the `lifetime.end` on `%8` at 21 and 22; its `lifetime.start` at 23; the `store` to `%8` and
the `lifetime.end` on `%7` at 24 and 25; the two `insertvalue`s of `%9` and `%8` into an `undef`
`[2 x ptr]` and the `lifetime.start` on `%7` at 26 to 28; the `store` of that pair to `%7`, the
`getelementptr` with two indices on `%7`, four `load`s, a `getelementptr` with one index and two
`insertelement`s (the first into `undef`), then the `lifetime.end` on `%7`, at 29 to 38; and the
`lifetime.end` calls on `%8` and `%9` at 39 and 40. For every context of gemv_kernel's program,
deliveries `w` and thread whose innermost frame `f` (above frames `rest`) runs the kernel at
statement 3 of `%6`, with memory `m`, the thread runs the block through the segments to the
branch (`Piece.Through`, by `Piece.through`), each segment's obligations a premise at its start
frame. -/
theorem gemv_segs :
    (summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 3 gemvStops).map
        (fun r => (r.1.map lifeShape, r.2.len, r.2.exit)) =
      some ([none, none, some (false, .reg 9, 0), some (true, .reg 9, 0), some (false, .reg 8, 1),
          some (true, .reg 8, 0), some (false, .reg 7, 1), some (true, .reg 7, 2),
          some (false, .reg 7, 9), some (false, .reg 8, 0), some (false, .reg 9, 0)], 7,
        .cond (.node 6) 43 44) ∧
    ∀ {c : Ctx}, c.prog = gemv.prog → ∀ (w : Nat → Option Val × Mem) {t : Thread} {m : Mem}
      {f : Frame} {rest : List Frame}, t.frames = f :: rest → f.fn = gemv.fn_0 →
      f.label = gemv.fn_0.b_0.label → f.pc = 3 →
      ∃ Ss L, summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 3 gemvStops =
        some (Ss, L) ∧ Piece.Through c gemv.fn_0.b_0.label rest L Ss w t m f := by
  have h : (summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 3 gemvStops).isSome =
      true := by
    decide +kernel
  obtain ⟨⟨Ss, L⟩, hx⟩ := Option.isSome_iff_exists.1 h
  refine ⟨by decide +kernel, ?_⟩
  intro c hP w t m f rest ht hfn hl hp
  exact ⟨Ss, L, hx, Piece.through hP hx w ht hfn hl hp⟩

/-- **The open twin, `%6` from its first statement**: the checker refuses statement 0, the first
`alloca` (`refusal`), so the block has no summary from 0 with the `alloca` flag off and the stops
`gemvStops` (`summarizePieces` is `none`). And the stops must name every marker: from statement 26
the checker takes the two `insertvalue`s and stops at the `lifetime.start` at 28 (`refusal`), so
from 3 without 28 among the stops there is no summary either. -/
theorem gemv_segs_twin :
    refusal gemv.prog gemv.fn_0 gemv.fn_0.b_0 0 = some 0 ∧
    (summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 0 gemvStops).isNone ∧
    refusal gemv.prog gemv.fn_0 gemv.fn_0.b_0 26 = some 28 ∧
    (summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 3 (gemvStops.erase 28)).isNone := by
  decide +kernel

/-- **gemv_kernel's whole `%6`, its `alloca`s included**: with the `alloca` flag on,
`summarizePieces` gives, from statement 0 of the entry block `%6` (`gemv.fn_0.b_0`) with the
stops `gemvStops`, the eleven segments of `gemv_segs` and the summary of statements 41 to 47 to
the conditional branch on node 6. The first segment, to the shuffle at 17, has 17 statements and
the effects of the three `alloca`s at 0, 1 and 2 (one cell of `i64` each). For every context of
gemv_kernel's program, deliveries `w` and thread whose innermost frame `f` (above frames `rest`)
runs the kernel at statement 0 of `%6`, with memory `m`, the thread runs the whole block through
the segments to the branch (`Piece.Through`, by `Piece.through`), the frames after the first
segment with the three blocks in front of `f`'s `alloca` blocks. -/
theorem gemv_segs_alloca :
    (summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 0 gemvStops true).map
        (fun r => (r.1.map lifeShape, r.2.len, r.2.exit)) =
      some ([none, none, some (false, .reg 9, 0), some (true, .reg 9, 0), some (false, .reg 8, 1),
          some (true, .reg 8, 0), some (false, .reg 7, 1), some (true, .reg 7, 2),
          some (false, .reg 7, 9), some (false, .reg 8, 0), some (false, .reg 9, 0)], 7,
        .cond (.node 6) 43 44) ∧
    (summarizeTo gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 0 17 true).map (fun S => (S.effs, S.len)) =
      some ([.alloca 6 0 0 (some (.int 64 1)), .alloca 6 1 1 (some (.int 64 1)),
        .alloca 6 2 2 (some (.int 64 1))], 17) ∧
    ∀ {c : Ctx}, c.prog = gemv.prog → ∀ (w : Nat → Option Val × Mem) {t : Thread} {m : Mem}
      {f : Frame} {rest : List Frame}, t.frames = f :: rest → f.fn = gemv.fn_0 →
      f.label = gemv.fn_0.b_0.label → f.pc = 0 →
      ∃ Ss L, summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 0 gemvStops true =
        some (Ss, L) ∧ Piece.Through c gemv.fn_0.b_0.label rest L Ss w t m f := by
  have h : (summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 0 gemvStops true).isSome =
      true := by
    decide +kernel
  obtain ⟨⟨Ss, L⟩, hx⟩ := Option.isSome_iff_exists.1 h
  refine ⟨by decide +kernel, by decide +kernel, ?_⟩
  intro c hP w t m f rest ht hfn hl hp
  exact ⟨Ss, L, hx, Piece.through hP hx w ht hfn hl hp⟩

/-- **The mutants of `gemv_segs_alloca`**: with the flag on, the stops without the shuffle at 17
give no summary (the checker refuses the shuffle inside a segment), nor do the stops without the
`lifetime.start` at 28; and with the flag off the first segment, to the shuffle at 17, has no
summary (the `alloca` at 0 is refused). -/
theorem gemv_segs_alloca_mutant :
    (summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 0 (gemvStops.erase 17) true).isNone ∧
    (summarizePieces gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 0 (gemvStops.erase 28) true).isNone ∧
    (summarizeTo gemv.prog gemv.fn_0 gemv.fn_0.b_0.label 0 17).isNone := by
  decide +kernel

end MojoProofTest.SymSeg
