import MojoProofTest.SymPhi

/-!
# `fmul contract` in the block checker: the naive matmul kernel's latch

The checker with `fmul contract` (`coversC`, MojoProof/Sym/Checker.lean) and its soundness
theorem (`Block.soundC`, MojoProof/Sym/Block.lean) on the latch `%52` of the naive matmul kernel
(`naive`, MojoProofTest/SymPhi.lean), which loads the two operands `%60` and `%64`, computes
`%65 = fmul contract float %60, %64` and `%66 = fadd contract float %48, %65`, and branches back to
the loop head `%46`, whose `phi` takes `%66`.

* `latch`, `latch_nodes`, `latch_covers`: the block's summary from position 0 with
  `fmul contract` in the fragment (`summarizeC`); `%65` is node 12, the `fmul contract` of the
  loads' nodes 7 and 11, and `%66` is node 13, the `fadd contract` of the entry register `%48` and
  node 12 whose second operand's `fmul contract` operands are the terms of nodes 7 and 11
  (`SNode.fbinP`); the checker `coversC` accepts it.
* `latch_refused`: the checker without `fmul contract` (`summarize`, `covers`) refuses the
  block.
* `latch_twins`: the summary with `%66`'s products dropped (an `SNode.fbin` node), with their
  terms swapped, or with `%65`'s `contract` flag cleared, is refused by `coversC`.
* `latch_prods`: `Block.soundC` on `latch_covers`: for every context of `naive`'s program and every
  thread at the latch's entry whose obligations hold, the thread runs the block to its terminator
  with `%65`'s `fmul contract` operands the values of the two loads' nodes, and none for `%66`.
* `latch_afterC`: after the latch, `%65`'s products are the loads' values with
  `Valuation.afterC`, and none with `Valuation.after`.
* `latch_edge`: `Ends.edgeC` after `Block.soundC`: the latch's branch enters `%46` after its
  `phi`s, at the valuation `Valuation.intoC` of the latch's.

Each result covers the program and block it names, not all programs.
-/

namespace MojoProofTest.SymContract

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi

/-- The naive kernel's latch `%52` from position 0 with `fmul contract` in the fragment
(`summarizeC`; the default summary if it refuses, which `latch_covers` excludes): the index
arithmetic and its `select`, the two `getelementptr`s and `load`s, `%65 = fmul contract`,
`%66 = fadd contract` and `br label %46`. -/
def latch : Summary := (summarizeC naive.prog naive.fn_0 naive.fn_0.b_6.label 0).getD default

/-- **The nodes of `%65` and `%66`**: `%65` is node 12, the `fmul contract` (flags `contract`
only) at step 12 of the loads' nodes 7 (statement 7, through node 6) and 11 (statement 11, through
node 10); `%66` is node 13, the `fadd contract` at step 13 of the entry register `%48` and node 12,
whose second operand's `fmul contract` operands are nodes 7 and 11; the block runs 14 statements
and branches to `%46`. -/
theorem latch_nodes :
    latch.regs.lookup (idx "65") = some (.node 12) ∧
    latch.nodes[12]? = some (.fbin .fmul { contract := true } .float 12 (.node 7) (.node 11)) ∧
    latch.regs.lookup (idx "66") = some (.node 13) ∧
    latch.nodes[13]? = some (.fbinP .fadd { contract := true } .float 13 (.reg (idx "48"))
      (.node 12) none (some (.node 7, .node 11))) ∧
    latch.nodes[7]? = some (.load naive.fn_0.b_6.label 7 (.node 6)) ∧
    latch.nodes[11]? = some (.load naive.fn_0.b_6.label 11 (.node 10)) ∧
    latch.len = 14 ∧
    latch.exit = .phi (.int 1 1) naive.fn_0.b_3.label naive.fn_0.b_3.label := by
  decide +kernel

/-- The block checker with `fmul contract` accepts `latch` with its own obligations. -/
theorem latch_covers :
    coversC naive.prog naive.fn_0 naive.fn_0.b_6.label 0 latch.obls latch = true := by
  decide +kernel

/-- The block checker without `fmul contract` refuses the latch: `summarize` gives no summary,
so `covers` rejects `latch`. -/
theorem latch_refused :
    summarize naive.prog naive.fn_0 naive.fn_0.b_6.label 0 = none ∧
    covers naive.prog naive.fn_0 naive.fn_0.b_6.label 0 latch.obls latch = false := by
  decide +kernel

/-- **The twins**: `latch` with node 13 an `fbin` node (`%66` reading no `fmul contract`
operands for `%65`), with node 13's operand terms swapped (nodes 11 and 7), or with node 12's
flags cleared (an `fmul` without `contract`), is refused by `coversC` with the same
obligations. -/
theorem latch_twins :
    coversC naive.prog naive.fn_0 naive.fn_0.b_6.label 0 latch.obls
      { latch with nodes := (latch.nodes.set 13
          (.fbin .fadd { contract := true } .float 13 (.reg (idx "48")) (.node 12))) } = false ∧
    coversC naive.prog naive.fn_0 naive.fn_0.b_6.label 0 latch.obls
      { latch with nodes := (latch.nodes.set 13
          (.fbinP .fadd { contract := true } .float 13 (.reg (idx "48")) (.node 12) none
            (some (.node 11, .node 7)))) } = false ∧
    coversC naive.prog naive.fn_0 naive.fn_0.b_6.label 0 latch.obls
      { latch with nodes := latch.nodes.set 12 (.fbin .fmul {} .float 12 (.node 7) (.node 11)) } =
        false := by
  decide +kernel

/-- The `fmul contract` operand terms of `%65`'s node are the loads' nodes 7 and 11, and `%66`'s
node has none (it is an `fadd`). -/
theorem latch_factors :
    (SVal.node 12).factors latch.nodes = some (.node 7, .node 11) ∧
    (SVal.node 13).factors latch.nodes = none := by
  decide +kernel

/-- **The products at the latch's end** (`Block.soundC`): for every context `c` of `naive`'s
program and thread whose innermost frame `f` (above frames `rest`) is at the latch's entry, with
memory `m`, if `latch`'s obligations hold under `f`'s entry valuation, the thread runs the block
to its terminator at a frame whose `fmul contract` operands for `%65` are the values of the loads'
nodes 7 and 11 (`prodVal`), and none for `%66`. -/
theorem latch_prods {c : Ctx} (hP : c.prog = naive.prog) {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = naive.fn_0)
    (hl : f.label = naive.fn_0.b_6.label) (hp : f.pc = 0)
    (hds : ∀ d ∈ latch.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) latch.nodes)) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + latch.len⟩ me ∧
      fe.prods (idx "65") = prodVal (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) latch.nodes) (.node 7, .node 11) ∧
      fe.prods (idx "66") = none := by
  obtain ⟨fe, me, hS, -, -, -, -, -, hpr, -⟩ := Block.soundC latch_covers hP ht hfn hl hp hds
  obtain ⟨h65, -, h66, -⟩ := latch_nodes
  refine ⟨fe, me, hS, ?_, ?_⟩
  · rw [hpr]
    simp only [prodsWith, Bool.cond_true, regProdIn, h65, latch_factors.1, Option.bind_some]
  · rw [hpr]
    simp only [prodsWith, Bool.cond_true, regProdIn, h66, latch_factors.2, Option.bind_none]

/-- **The latch's back edge** (`Block.soundC`, `Ends.edgeC`): for every context `c` of `naive`'s
program and thread whose innermost frame `f` (above frames `rest`) is at the latch's entry, with
memory `m`, if `latch`'s obligations hold under `f`'s entry valuation, the thread's steps run the
latch and its `br label %46`, whose step enters the loop head `%46` after its two `phi`s
(position 2) with the entry valuation `Valuation.intoC` of the latch's: the table's
`fmul contract` operands, with `%46`'s `phi`s set. -/
theorem latch_edge {c : Ctx} (hP : c.prog = naive.prog) {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = naive.fn_0)
    (hl : f.label = naive.fn_0.b_6.label) (hp : f.pc = 0)
    (hds : ∀ d ∈ latch.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) latch.nodes)) :
    ∃ t₁ m₁ f', Steps c t m t₁ m₁ ∧
      step c t₁ m₁ = .ok (.next ⟨f' :: rest, t.k + latch.len + 1⟩ m₁) ∧
      f'.label = naive.fn_0.b_3.label ∧ f'.pc = 2 ∧
      Valuation.entry c (t.k + latch.len + 1) m₁ f' =
        (Valuation.entry c t.k m f).intoC naive.fn_0.b_6.label latch := by
  have hx := latch_nodes.2.2.2.2.2.2.2
  obtain ⟨t₁, m₁, f', h1, h2, -, h4, h5, -, -, h8⟩ :=
    Ends.edgeC (V := Valuation.entry c t.k m f) (d := naive.fn_0.b_3.label) rfl
      (Block.soundC latch_covers hP ht hfn hl hp hds)
      (by rw [hx]; rfl)
  refine ⟨t₁, m₁, f', h1, h2, h4, ?_, h8⟩
  rw [h5, hx]
  show phiCount f.fn naive.fn_0.b_3.label = 2
  rw [hfn]
  decide +kernel

/-- **The products after the latch**: for every valuation `V`, `%65`'s `fmul contract` operands
after the latch are the values of the loads' nodes 7 and 11 with `fmul contract`
(`Valuation.afterC`, the table's `regProdIn`), and none without it (`Valuation.after`,
`regProd`). -/
theorem latch_afterC (V : Valuation) :
    (V.afterC latch).prods (idx "65") = prodVal V (vals V latch.nodes) (.node 7, .node 11) ∧
    (V.after latch).prods (idx "65") = none := by
  obtain ⟨h65, -⟩ := latch_nodes
  refine ⟨?_, ?_⟩
  · simp only [Valuation.afterC, Valuation.afterWith, prodsWith, Bool.cond_true, regProdIn, h65,
      latch_factors.1, Option.bind_some]
  · simp only [Valuation.after, regProd, h65]

end MojoProofTest.SymContract
