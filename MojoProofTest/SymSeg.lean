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

Segments that end at a lifetime marker (`summarizeLife`, `Seg.lifetime`):

* `ln_life`: block `%453`'s statements 1 to 9 are the segment that ends at the `lifetime.end` on
  `%12` of statement 10, with `ln_after`'s effects; from 11, after the marker, the checker takes
  statements 11 to 15 and first refuses statement 16, the `rsqrt.approx` call.
* `ln_life_twin`: block `%151` (ln.fn_0.b_30) ends and starts the lifetimes of `%12` and `%11`
  (statements 6, 7, 9 and 10), each the end of a segment, the one from 8 with the `store` to
  `%12`; the checker refuses statement 11, the `store` of `zeroinitializer` to `%11`.
* `ln_life_end`: on a thread at statement 1 of `%453`, the segment's steps to the `lifetime.end`
  and the step past it, on the memory with `%12`'s block's lifetime ended (`Seg.lifetime_ptr`).

Tests of five blocks of three kernels; `Seg.sound`, `Seg.resume`, `Seg.through` and
`Seg.lifetime` cover every program, `SNode.eval_globalAt` every valuation and statement, and the
lemmas of MojoProof/Sym/LoadAfter.lean every valuation, statements and effects.
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
        ⟨[], [], [], [], false⟩).map (fun σ => (σ.nodes, σ.effs)) =
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
        ⟨[], [], [], [], false⟩).map (fun σ => (σ.nodes.drop 2, σ.effs)) =
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
        ⟨[], [], [], [], false⟩).map (fun σ => (σ.nodes.drop 2, σ.effs.drop 2)) =
      some ([.globalAt ln.fn_0.b_42.label 3 0,
        .loadAfter ln.fn_0.b_42.label 3 (.node 2) (lnEffs.take 2)],
        [.load ln.fn_0.b_42.label 3 (.node 2)]) := by
  decide +kernel

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
from 11 is 11, the `store` of `zeroinitializer` to `%11` (`refusal`). -/
theorem ln_life_twin :
    (summarizeLife ln.prog ln.fn_0 ln.fn_0.b_30.label 6 6).map (·.2) = some (false, .reg 12) ∧
    (summarizeLife ln.prog ln.fn_0 ln.fn_0.b_30.label 7 7).map (·.2) = some (true, .reg 12) ∧
    (summarizeLife ln.prog ln.fn_0 ln.fn_0.b_30.label 8 9).map (·.2) = some (false, .reg 11) ∧
    (summarizeLife ln.prog ln.fn_0 ln.fn_0.b_30.label 10 10).map (·.2) = some (true, .reg 11) ∧
    refusal ln.prog ln.fn_0 ln.fn_0.b_30 11 = some 11 := by
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

end MojoProofTest.SymSeg
