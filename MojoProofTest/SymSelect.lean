import MojoProof.Sym.Payload
import MojoProofTest.SymPhi
import MojoProofTest.Labels

/-!
# Integer `select` and `llvm.smax` in the block checker: the naive matmul kernel's entry block

The nodes `SNode.select` and `SNode.minmax` (MojoProof/Sym/Term.lean) on the entry block `%6` of
the naive matmul kernel (`naive`, MojoProofTest/SymPhi.lean), which computes the loop bound
`%16 = call i64 @llvm.smax.i64(i64 %15, i64 0)` and the exit test
`%43 = select i1 %41, i1 true, i1 %42` (`%41 = icmp sge i64 %24, %13`, `%42 = icmp sge i64 %35,
%14`: the thread's row and column against the matrix's) before its `br i1 %43`.

* `entry`, `entry_nodes`, `entry_covers`: the block's summary from position 0; `%16` is the
  signed-maximum node of `%15`'s node and the constant 0, `%43` the `select` node of `%41`'s node,
  the constant `true` and `%42`'s node, and the exit branches on `%43`; the checker accepts it.
* `entry_twins`: the summary with the maximum's node made unsigned, or made a minimum, or with
  the `select`'s operands swapped, is refused.
* `head`, `head_regs`: the block from position 9 (the maximum, the special-register reads, the
  index arithmetic, the `getelementptr`, the compares, the `select` and the branch), run by
  `Block.sound` under the context `ctxS i` (thread `i` of `launch4` of MojoProofTest/SymRun.lean,
  with `naive`'s program) on `mem0` at the frame `frameS k rows cols` (`%15 = k`, `%13 = rows`,
  `%14 = cols`, `%10` pointing at block 1): with `k = -3` and the matrix `4 × 1`, every thread
  `i < 4` ends with `%16 = 0` (the maximum of `-3` and 0) and `%43 = 0` (row `i < 4` and column
  `0 < 1`: the `select` gives `%42`, false); with `k = 5` and the matrix `2 × 1`, thread 3 ends
  with `%16 = 5` and `%43 = 1` (row `3 ≥ 2`: the `select` gives `true`).
* `head_unsigned`: the twin of the semantics, an unsigned maximum node of the same operands gives
  `2 ^ 64 - 3` at `k = -3`, not 0.
* `head_payload`: the checks of MojoProof/Sym/Payload.lean on `head` with its exit replaced by
  `ret void` (so that only the nodes are checked): with `%14` payload, the `select`'s operand
  `%42` is payload and the summary is oblivious and passes `Summary.payOk`; with `%13` payload,
  the `select`'s condition `%41` is, and it is neither oblivious nor passes `payOk`; with `%15`
  and `%16` payload, the maximum node is payload and the summary is oblivious, passes `payOk`
  and agrees with the labelling.

Each result covers the program, contexts, memory and frames it names, not all programs.
-/

namespace MojoProofTest.SymSelect

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymRun
open MojoProofTest.SymPhi MojoProofTest.Labels

/-- The naive kernel's entry block `%6` from position 0: its three loads of the arguments' structs,
the `extractvalue`s of their pointers, the `sext`s, `%16 = smax(%15, 0)`, the special-register
reads, the index arithmetic, `%40 = getelementptr`, the compares `%41`, `%42`,
`%43 = select i1 %41, i1 true, i1 %42` and `br i1 %43`. -/
sym_summary entry := naive.prog naive.fn_0 naive.fn_0.b_0.label 0

/-- **The nodes of `%16` and `%43`**: `%16` is node 9, the signed maximum (`.minmax true true`)
of node 8 (`%15`) and the 64-bit constant 0; `%43` is node 36, the 1-bit `select` of node 34
(`%41`), the constant `true` and node 35 (`%42`); the block exits on `%43` to `%44` or `%45`. -/
theorem entry_nodes :
    entry.regs.lookup (idx "16") = some (.node 9) ∧
    entry.nodes[9]? = some (.minmax true true (.node 8) (.int 64 0)) ∧
    entry.regs.lookup (idx "43") = some (.node 36) ∧
    entry.nodes[36]? = some (.select 1 (.node 34) (.int 1 1) (.node 35)) ∧
    entry.exit = .cond (.node 36) naive.fn_0.b_1.label naive.fn_0.b_2.label := by
  decide +kernel

/-- The block checker accepts `entry` with its own obligations. -/
theorem entry_covers :
    covers naive.prog naive.fn_0 naive.fn_0.b_0.label 0 entry.obls entry = true := by
  decide +kernel

/-- **The twins**: `entry` with node 9 an unsigned maximum, or a signed minimum, or with node 36's
operands swapped (`select %41, %42, true`), is refused with the same obligations. -/
theorem entry_twins :
    covers naive.prog naive.fn_0 naive.fn_0.b_0.label 0 entry.obls
      { entry with nodes := entry.nodes.set 9 (.minmax false true (.node 8) (.int 64 0)) } =
        false ∧
    covers naive.prog naive.fn_0 naive.fn_0.b_0.label 0 entry.obls
      { entry with nodes := entry.nodes.set 9 (.minmax true false (.node 8) (.int 64 0)) } =
        false ∧
    covers naive.prog naive.fn_0 naive.fn_0.b_0.label 0 entry.obls
      { entry with nodes := entry.nodes.set 36 (.select 1 (.node 34) (.node 35) (.int 1 1)) } =
        false := by
  decide +kernel

/-- `%6` from position 9, after its loads, `extractvalue`s and `sext`s: `%16 = smax(%15, 0)`
through `br i1 %43`, reading `%10`, `%13`, `%14` and `%15` as entry registers. -/
sym_summary head := naive.prog naive.fn_0 naive.fn_0.b_0.label 9

/-- The block checker accepts `head` with its own obligations. -/
theorem head_covers :
    covers naive.prog naive.fn_0 naive.fn_0.b_0.label 9 head.obls head = true := by
  decide +kernel

/-- The context of thread `i` of `launch4` (`ctx4 i`) with `naive`'s program. -/
def ctxS (i : Nat) : Ctx := { ctx4 i with prog := naive.prog }

/-- The frame at `%6`'s position 9 with `%15 = k` (64 bits), the matrix's rows `%13 = rows` and
columns `%14 = cols`, and `%10` pointing at block 1. -/
def frameS (k : Int) (rows cols : Nat) : Frame :=
  ⟨naive.fn_0, naive.fn_0.b_0.label, 9,
    fun r => if r = idx "15" then some (.bits 64 (BitVec.ofInt 64 k))
      else if r = idx "13" then some (.bits 64 (BitVec.ofNat 64 rows))
      else if r = idx "14" then some (.bits 64 (BitVec.ofNat 64 cols))
      else if r = idx "10" then some (.ptr ⟨1, 0⟩)
      else none,
    fun _ => none, [], none⟩

/-- `head`'s obligations hold at `frameS k rows cols` under `ctxS i` on `mem0`, and the registers
`%16` and `%43` its summary gives are the words `a` and `b`. -/
def headAt (i : Nat) (k : Int) (rows cols a b : Nat) : Prop :=
  (∀ d ∈ head.obls, d.Holds (Valuation.entry (ctxS i) 0 mem0 (frameS k rows cols))
    (vals (Valuation.entry (ctxS i) 0 mem0 (frameS k rows cols)) head.nodes)) ∧
  (regVal (Valuation.entry (ctxS i) 0 mem0 (frameS k rows cols))
    (vals (Valuation.entry (ctxS i) 0 mem0 (frameS k rows cols)) head.nodes) head.regs
    (idx "16")).bind Val.word? = some a ∧
  (regVal (Valuation.entry (ctxS i) 0 mem0 (frameS k rows cols))
    (vals (Valuation.entry (ctxS i) 0 mem0 (frameS k rows cols)) head.nodes) head.regs
    (idx "43")).bind Val.word? = some b

/-- `headAt` gives the run: `Block.sound` with `head_covers` runs the thread from
`frameS k rows cols` to the block's terminator, at a frame whose `%16` and `%43` are the words
`a` and `b`. -/
theorem headAt.run {i : Nat} {k : Int} {rows cols a b : Nat} (h : headAt i k rows cols a b) :
    ∃ fe me, Steps (ctxS i) ⟨[frameS k rows cols], 0⟩ mem0 ⟨[fe], 0 + head.len⟩ me ∧
      (fe.regs (idx "16")).bind Val.word? = some a ∧
      (fe.regs (idx "43")).bind Val.word? = some b := by
  obtain ⟨fe, me, hS, -, -, -, -, hr, -⟩ := Block.sound head_covers (c := ctxS i)
    (t := ⟨[frameS k rows cols], 0⟩) (m := mem0) (f := frameS k rows cols) (rest := []) rfl rfl
    rfl rfl rfl h.1
  exact ⟨fe, me, hS, by rw [hr]; exact h.2.1, by rw [hr]; exact h.2.2⟩

/-- **The maximum and the `select` on a run**: for every thread `i < 4` of `launch4`, from
`frameS (-3) 4 1` the thread runs `head` to its terminator with `%16 = 0` (the signed maximum of
`-3` and 0) and `%43 = 0` (row `i < 4` and column `0 < 1`, so the `select` gives `%42`, false);
thread 3 from `frameS 5 2 1` ends with `%16 = 5` and `%43 = 1` (row `3 ≥ 2`, so the `select`
gives its constant `true`). -/
theorem head_regs :
    (∀ i < 4, ∃ fe me, Steps (ctxS i) ⟨[frameS (-3) 4 1], 0⟩ mem0 ⟨[fe], 0 + head.len⟩ me ∧
      (fe.regs (idx "16")).bind Val.word? = some 0 ∧
      (fe.regs (idx "43")).bind Val.word? = some 0) ∧
    ∃ fe me, Steps (ctxS 3) ⟨[frameS 5 2 1], 0⟩ mem0 ⟨[fe], 0 + head.len⟩ me ∧
      (fe.regs (idx "16")).bind Val.word? = some 5 ∧
      (fe.regs (idx "43")).bind Val.word? = some 1 := by
  have h : (∀ i < 4, headAt i (-3) 4 1 0 0) ∧ headAt 3 5 2 1 5 1 := by
    unfold headAt
    decide +kernel
  exact ⟨fun i hi => (h.1 i hi).run, h.2.run⟩

/-- **The twin of the semantics**: under the valuation of `frameS (-3) 4 1`, the unsigned maximum
of `%15` and 0 is `2 ^ 64 - 3` (`-3` read as unsigned), where `head`'s signed node gives 0. -/
theorem head_unsigned :
    ((SNode.minmax false true (.reg (idx "15")) (.int 64 0)).eval
      (Valuation.entry (ctxS 0) 0 mem0 (frameS (-3) 4 1)) []).toOption.bind Val.word? =
        some (2 ^ 64 - 3) := by
  decide +kernel

/-- `head` with its exit replaced by `ret void`, so that the payload checks read its nodes
only. -/
def headRet : Summary := { head with exit := .ret }

/-- **The payload checks on a `select` and a maximum**: with `%14` payload, the `select`'s operand
`%42` is payload and `headRet` is oblivious and passes `Summary.payOk`; with `%13` payload, the
`select`'s condition `%41` is payload, and `headRet` is neither oblivious nor passes `payOk`; with
`%15` and `%16` payload, the maximum node of `%16` is payload, and `headRet` is oblivious, passes
`payOk` and agrees with the labelling. -/
theorem head_payload :
    headRet.oblivious (labIn naive.fn_0 ["14"]) naive.fn_0 = true ∧
    headRet.payOk (labIn naive.fn_0 ["14"]) naive.fn_0 = true ∧
    headRet.oblivious (labIn naive.fn_0 ["13"]) naive.fn_0 = false ∧
    headRet.payOk (labIn naive.fn_0 ["13"]) naive.fn_0 = false ∧
    headRet.oblivious (labIn naive.fn_0 ["15", "16"]) naive.fn_0 = true ∧
    headRet.payOk (labIn naive.fn_0 ["15", "16"]) naive.fn_0 = true ∧
    headRet.agrees (labIn naive.fn_0 ["15", "16"]) naive.fn_0 = true := by
  decide +kernel

end MojoProofTest.SymSelect
