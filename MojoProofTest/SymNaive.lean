import MojoProofTest.SymContract
import MojoProof.Sym.Info

/-!
# The block checker on every block of the naive matmul kernel

The naive matmul kernel (`naive`, MojoProofTest/SymPhi.lean) has nine blocks: the entry `%6`,
which computes the thread's row and column and branches on the bounds; `%44` (out of bounds:
`br label %69`); `%45` (the loop's preheader: `br label %46`); the loop head `%46` with the
`phi`s `%47` (counter) and `%48` (accumulator); `%50` (`br label %52`); the exit `%51`
(`br label %67`); the latch `%52` (the loads, `%65 = fmul contract`, `%66 = fadd contract`);
`%67` (the store of `%68 = phi [%48, %51]`); and `%69` (`ret void`).

* `naive_refusals`: the checker's verdict (`refusal`, the statement at which `summarize` stops)
  on every block from its position after its `phi`s: it accepts every block but `%45`, refused at
  its terminator (the incoming operand of `%48` from `%45` is the float constant `0.0`, which
  `SState.phiConds` refuses), and `%52`, refused at its `fmul contract` (statement 12).
* `naive_refusalsC`: the checker with `fmul contract` (`summarizeC`) accepts every block but
  `%45`.
* `skip`, `body`, `skip_body_covers`: the summaries of `%44` and `%50`, the blocks of no
  statement that branch to `%69` and to `%52`; the checker accepts both, and `%69`'s summary is
  `Kernels.vadd.b3` (`ret void` alone).

* `trip1_covers`, `trip1_latch`, `trip1_round`: `%46 → %50`, accepted by the path checker with
  `phi`s, then the latch `%52`, accepted by `coversC` (`Block.sound_pathC`), and its branch back
  into `%46` after its `phi`s (`Ends.edgeC`): one trip of the loop, from the head to the head;
  the path checker refuses the path through the latch.

The other blocks' tests: `%6` (`entry_covers`, MojoProofTest/SymSelect.lean); `%46`, `%51`,
`%67`, and `%45`'s refusal (`trip0_covers`, `trip0_twins`, MojoProofTest/SymPhi.lean); `%52`
(`naive_latch_refusal`, MojoProofTest/SymLoop.lean, and `latch_covers`,
MojoProofTest/SymContract.lean).

Each result covers the program and blocks it names, not all programs.
-/

namespace MojoProofTest.SymNaive

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi

/-- **The verdict on every block**: from the position after its `phi`s (`phiCount`), the block
checker accepts (`refusal` is `none`) `%6`, `%44`, `%46`, `%50`, `%51`, `%67` and `%69`, refuses
`%45` at its terminator (position 0: the float constant `0.0` it passes to `%48`) and `%52` at
statement 12 (`%65 = fmul contract`). -/
theorem naive_refusals :
    naive.fn_0.blocks.toList.map (fun b => (b.label, refusal naive.prog naive.fn_0 b
      (phiCount naive.fn_0 b.label))) =
    [(naive.fn_0.b_0.label, none), (naive.fn_0.b_1.label, none), (naive.fn_0.b_2.label, some 0),
      (naive.fn_0.b_3.label, none), (naive.fn_0.b_4.label, none), (naive.fn_0.b_5.label, none),
      (naive.fn_0.b_6.label, some 12), (naive.fn_0.b_7.label, none),
      (naive.fn_0.b_8.label, none)] := by
  decide +kernel

/-- **The verdict with `fmul contract`**: from the position after its `phi`s, `summarizeC` gives
a summary of every block but `%45`. -/
theorem naive_refusalsC :
    naive.fn_0.blocks.toList.map (fun b => (b.label,
      (summarizeC naive.prog naive.fn_0 b.label (phiCount naive.fn_0 b.label)).isSome)) =
    [(naive.fn_0.b_0.label, true), (naive.fn_0.b_1.label, true), (naive.fn_0.b_2.label, false),
      (naive.fn_0.b_3.label, true), (naive.fn_0.b_4.label, true), (naive.fn_0.b_5.label, true),
      (naive.fn_0.b_6.label, true), (naive.fn_0.b_7.label, true),
      (naive.fn_0.b_8.label, true)] := by
  decide +kernel

/-- `%44`, the block a thread out of bounds takes: `br label %69`. -/
sym_summary skip := naive.prog naive.fn_0 naive.fn_0.b_1.label 0

/-- `%50`, the block the loop head branches to while the counter is below the bound:
`br label %52`. -/
sym_summary body := naive.prog naive.fn_0 naive.fn_0.b_4.label 0

/-- **`%44`, `%50` and `%69`**: `skip` and `body` have no node and branch to `%69` and to the
latch `%52`, the checker accepts both with their own obligations, and it accepts
`Kernels.vadd.b3` (`ret void` alone) as `%69`'s summary. -/
theorem skip_body_covers :
    skip.nodes = [] ∧ skip.exit = .br naive.fn_0.b_8.label ∧
    covers naive.prog naive.fn_0 naive.fn_0.b_1.label 0 skip.obls skip = true ∧
    body.nodes = [] ∧ body.exit = .br naive.fn_0.b_6.label ∧
    covers naive.prog naive.fn_0 naive.fn_0.b_4.label 0 body.obls body = true ∧
    covers naive.prog naive.fn_0 naive.fn_0.b_8.label 0 Kernels.vadd.b3.obls Kernels.vadd.b3 =
      true := by
  decide +kernel

/-- **A trip up to the latch, and its twin**: the path checker with `phi`s accepts `%46 → %50`
from `%46`'s position 2, and refuses `%46 → %50 → %52` (the checker without `fmul contract`
refuses the latch `%52`, `latch_refused`). -/
theorem trip1_covers :
    coversPathI naive.prog naive.fn_0 2
      [(naive.fn_0.b_3.label, hdr.obls, hdr), (naive.fn_0.b_4.label, body.obls, body)] = true ∧
    coversPathI naive.prog naive.fn_0 2
      [(naive.fn_0.b_3.label, hdr.obls, hdr), (naive.fn_0.b_4.label, body.obls, body),
        (naive.fn_0.b_6.label, SymContract.latch.obls, SymContract.latch)] = false := by
  decide +kernel

/-- **A trip of the loop to the latch's end** (`Block.sound_pathC`): for every context `c` of
`naive`'s program and thread whose innermost frame `f` (above frames `rest`) is at the loop head
`%46`'s position 2, with memory `m`: if the premises of `%46 → %50` hold (`WalkI`: among them,
the head branches to `%50`) and the latch's obligations hold at its entry valuation, the thread's
steps run `%46`, `%50` and the latch `%52`, which ends with the table's `fmul contract` operands
(`EndsC`). -/
theorem trip1_latch {c : Ctx} (hP : c.prog = naive.prog) {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = naive.fn_0)
    (hl : f.label = naive.fn_0.b_3.label) (hp : f.pc = 2)
    (hW : WalkI (Valuation.entry c t.k m f)
      [(naive.fn_0.b_3.label, hdr.obls, hdr), (naive.fn_0.b_4.label, body.obls, body)])
    (hds : ∀ d ∈ SymContract.latch.obls, d.Holds
      (((Valuation.entry c t.k m f).into naive.fn_0.b_3.label hdr).into naive.fn_0.b_4.label body)
      (vals (((Valuation.entry c t.k m f).into naive.fn_0.b_3.label hdr).into
        naive.fn_0.b_4.label body) SymContract.latch.nodes)) :
    EndsC c t m f rest
      (((Valuation.entry c t.k m f).into naive.fn_0.b_3.label hdr).into naive.fn_0.b_4.label body,
        naive.fn_0.b_6.label, SymContract.latch) := by
  obtain ⟨-, -, -, -, hb, -, -⟩ := skip_body_covers
  exact Block.sound_pathC hP [(naive.fn_0.b_4.label, body.obls, body)] trip1_covers.1 ht hfn hl hp
    hW rfl (by rw [hb]; rfl) (by rw [hb]; exact SymContract.latch_covers) hds

/-- **One trip of the loop, from the head back to the head** (`trip1_latch`, `Ends.edgeC`): for
every context `c` of `naive`'s program and thread whose innermost frame `f` (above frames `rest`)
is at the loop head `%46`'s position 2, with memory `m`, under the premises of `trip1_latch`, the
thread's steps run `%46`, `%50` and the latch `%52`, and the latch's branch enters `%46` again
after its two `phi`s (position 2) with the entry valuation `Valuation.intoC` of the latch's. -/
theorem trip1_round {c : Ctx} (hP : c.prog = naive.prog) {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = naive.fn_0)
    (hl : f.label = naive.fn_0.b_3.label) (hp : f.pc = 2)
    (hW : WalkI (Valuation.entry c t.k m f)
      [(naive.fn_0.b_3.label, hdr.obls, hdr), (naive.fn_0.b_4.label, body.obls, body)])
    (hds : ∀ d ∈ SymContract.latch.obls, d.Holds
      (((Valuation.entry c t.k m f).into naive.fn_0.b_3.label hdr).into naive.fn_0.b_4.label body)
      (vals (((Valuation.entry c t.k m f).into naive.fn_0.b_3.label hdr).into
        naive.fn_0.b_4.label body) SymContract.latch.nodes)) :
    ∃ t₁ m₁ f', Steps c t m t₁ m₁ ∧
      step c t₁ m₁ = .ok (.next ⟨f' :: rest,
        (((Valuation.entry c t.k m f).into naive.fn_0.b_3.label hdr).into naive.fn_0.b_4.label
          body).k + SymContract.latch.len + 1⟩ m₁) ∧
      f'.label = naive.fn_0.b_3.label ∧ f'.pc = 2 ∧
      Valuation.entry c ((((Valuation.entry c t.k m f).into naive.fn_0.b_3.label hdr).into
          naive.fn_0.b_4.label body).k + SymContract.latch.len + 1) m₁ f' =
        (((Valuation.entry c t.k m f).into naive.fn_0.b_3.label hdr).into naive.fn_0.b_4.label
          body).intoC naive.fn_0.b_6.label SymContract.latch := by
  have hx := SymContract.latch_nodes.2.2.2.2.2.2.2
  obtain ⟨hc1, hf1, -⟩ :=
    Valuation.into_k ((Valuation.entry c t.k m f).into naive.fn_0.b_3.label hdr)
      naive.fn_0.b_4.label body
  obtain ⟨hc2, hf2, -⟩ := Valuation.into_k (Valuation.entry c t.k m f) naive.fn_0.b_3.label hdr
  obtain ⟨t₁, m₁, f', h1, h2, -, h4, h5, -, -, h8⟩ :=
    Ends.edgeC (d := naive.fn_0.b_3.label) (hc1.trans hc2) (trip1_latch hP ht hfn hl hp hW hds)
      (by rw [hx]; rfl)
  refine ⟨t₁, m₁, f', h1, h2, h4, ?_, h8⟩
  rw [h5, hx, hf1, hf2]
  show phiCount f.fn naive.fn_0.b_3.label = 2
  rw [hfn]
  decide +kernel

end MojoProofTest.SymNaive
