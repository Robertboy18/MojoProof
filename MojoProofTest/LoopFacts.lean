import MojoProofTest.SymNaive
import MojoProofTest.SymSelect
import MojoProofTest.SymLoop
import MojoProof.Sym.LoopFacts

/-!
# Facts at the heads of the naive matrix product's loop, and of two counting loops

Instances of MojoProof/Sym/LoopFacts.lean at the naive matrix product's loop `naiveL`
(`%46 → %50 → %52` with the path out `%51 → %67 → %69`, MojoProofTest/SymNaive.lean), the loop
of the thread's sequence of loops after the entry path `%6 → %45` (`SymSelect.entry`, then
`SymPhi.pre`):

* `naive_kept`: the registers the loop reads and keeps (`LoopSeg.kept`) are the bound `%16`, the
  row and column offsets `%26` and `%37`, the pointers `%11` and `%12` to `A` and `B`, and the
  output cell's pointer `%40`; `naive_kept_round`: each keeps its value after any number of
  rounds (`LoopSeg.kept_round`).
* `naive_loads`: the round reads memory only through `%11` and `%12`, which it keeps
  (`LoopSeg.loadsFrom`); `naive_elem`, `naive_only`: so for every valuation of the kernel's
  function whose `%11` and `%12` point to blocks other than `o`, `Elem` and `Elem.Only` at `o`
  hold after any number of rounds if they held at the head (`Valuation.iterate_elem`,
  `Valuation.iterate_only`).
* `naive_blocks`: and the memory's blocks and next block number after any number of rounds are
  the head's (`Valuation.iterate_blocks`), for every valuation of the kernel's function with
  pointers at `%11` and `%12`.
* `naive_steps`: for a thread whose entry valuation has step count `k`, round `j`'s head is
  entered at step `k + 39 + 18 j` and its latch at `k + 42 + 18 j` (`LoopSeg.stepAt_k`), so the
  latch's `fmul` `%65` and `fadd` `%66` (offsets 12 and 13) are at steps `k + 54 + 18 j` and
  `k + 55 + 18 j`, the steps whose oracle numbers the thread's invariant reads
  (`NaiveThread.oN`).

And at the two counting loops `loop1` and `loop2` of `cnt2` (MojoProofTest/SymLoop.lean), which
store: `cnt2_kept` (the bound `%10` and the pointers `%11` and `%16`), `cnt2_stores` (the check
`LoopSeg.loadsFrom` refuses a loop path that stores) and `cnt2_steps` (`LoopSeg.steps_k`).

Tests of three loops of two programs; the library results cover every program and loop.
-/

namespace MojoProofTest.LoopFacts

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.SymNaive

/-- **The registers the naive loop keeps**: `naiveL`'s loop path and path out read and its loop
path keeps the bound `%16`, the offsets `%26` and `%37`, the pointers `%11` and `%12` and the
output cell's pointer `%40`, in the order of their first read (`LoopSeg.kept`). -/
theorem naive_kept : naiveL.kept naive.fn_0 =
    [idx "16", idx "26", idx "11", idx "37", idx "12", idx "40"] := by
  decide +kernel

/-- For every valuation `V` of the naive kernel's function, register `r` that `naiveL` keeps
(`naive_kept`) and value `v` of `r` at `V`: `r` is `v` after any number of rounds
(`LoopSeg.kept_round`). -/
theorem naive_kept_round {V : Valuation} (hF : V.fn = naive.fn_0) {r : Nat}
    (hr : r ∈ [idx "16", idx "26", idx "11", idx "37", idx "12", idx "40"]) {v : Val}
    (hv : V.regs r = some v) (i : Nat) :
    ((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[i] V).regs r = some v :=
  LoopSeg.kept_round (by rw [naive_kept]; exact hr) hF hv i

/-- **The naive loop's round only reads, through `%11` and `%12`**: its blocks' effects are
loads through pointers based at `%11` and `%12`, which it keeps (`LoopSeg.loadsFrom`). -/
theorem naive_loads : naiveL.loadsFrom naive.fn_0 [idx "11", idx "12"] = true := by
  decide +kernel

/-- The premise of `Valuation.iterate_loads` at `naiveL` from pointers `%11` and `%12` to blocks
of `Q`. -/
theorem naive_bases {V : Valuation} {pA pB : Ptr} {Q : Nat → Prop}
    (hA : V.regs (idx "11") = some (.ptr pA)) (hB : V.regs (idx "12") = some (.ptr pB))
    (hAo : Q pA.block) (hBo : Q pB.block) :
    ∀ r ∈ [idx "11", idx "12"], ∃ v, V.regs r = some v ∧ v.NamesIn Q := by
  intro r hr
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hr
  rcases hr with rfl | rfl
  · exact ⟨_, hA, hAo⟩
  · exact ⟨_, hB, hBo⟩

/-- For every valuation of the naive kernel's function whose `%11` and `%12` point to blocks
other than `o`, and `Elem` at `o` at its memory: `Elem` at `o` holds after any number of rounds
(`Valuation.iterate_elem`). -/
theorem naive_elem {V : Valuation} (hF : V.fn = naive.fn_0) {pA pB : Ptr} {o : Nat}
    (hA : V.regs (idx "11") = some (.ptr pA)) (hB : V.regs (idx "12") = some (.ptr pB))
    (hAo : pA.block ≠ o) (hBo : pB.block ≠ o) {m₀ : Mem} {w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {n : Nat} (hm : Elem m₀ o w cell bs n V.mem) (i : Nat) :
    Elem m₀ o w cell bs n ((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[i] V).mem :=
  Valuation.iterate_elem naive_loads hF (naive_bases (Q := (· ≠ o)) hA hB hAo hBo) hm i

/-- For every valuation of the naive kernel's function whose `%11` and `%12` point to blocks
other than `o`, and `Elem.Only` at `o` at its memory: `Elem.Only` at `o` holds after any number
of rounds (`Valuation.iterate_only`). -/
theorem naive_only {V : Valuation} (hF : V.fn = naive.fn_0) {pA pB : Ptr} {o : Nat}
    (hA : V.regs (idx "11") = some (.ptr pA)) (hB : V.regs (idx "12") = some (.ptr pB))
    (hAo : pA.block ≠ o) (hBo : pB.block ≠ o) {T : Nat → Prop} (hm : Elem.Only o T V.mem)
    (i : Nat) :
    Elem.Only o T ((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[i] V).mem :=
  Valuation.iterate_only naive_loads hF (naive_bases (Q := (· ≠ o)) hA hB hAo hBo) hm i

/-- For every valuation of the naive kernel's function whose `%11` and `%12` are pointers, and
count `i`: after `i` rounds the memory has `V`'s blocks and next block number
(`Valuation.iterate_blocks`), the premise of `Mem.Buffer.of_block`, `Mem.Fits.of_block` and
`Mem.Holds.of_block`. -/
theorem naive_blocks {V : Valuation} (hF : V.fn = naive.fn_0) {pA pB : Ptr}
    (hA : V.regs (idx "11") = some (.ptr pA)) (hB : V.regs (idx "12") = some (.ptr pB)) (i : Nat) :
    ((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[i] V).mem.blocks = V.mem.blocks ∧
      ((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[i] V).mem.next = V.mem.next :=
  Valuation.iterate_blocks naive_loads hF (fun r h => by
    obtain ⟨v, hv, -⟩ := naive_bases (Q := fun _ => True) hA hB trivial trivial r h
    simp [hv]) i

/-- **The steps of the naive loop's round `j`**, for every valuation `V` at the thread's entry
and every `j`: after the entry path `%6 → %45` and `j` rounds, the head (block 0) is entered at
step `V.k + 39 + 18 j` and the latch (block 2) at `V.k + 42 + 18 j` (`LoopSeg.stepAt_k`); the
latch's `fmul` `%65` and `fadd` `%66` are its statements 12 and 13. -/
theorem naive_steps (V : Valuation) (j : Nat) :
    ((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[j]
        (Valuation.roundWith true naive.fn_0.b_0.label SymSelect.entry
          [(naive.fn_0.b_2.label, pre.obls, pre)] V)).k = V.k + 39 + 18 * j ∧
      (((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[j]
        (Valuation.roundWith true naive.fn_0.b_0.label SymSelect.entry
          [(naive.fn_0.b_2.label, pre.obls, pre)] V)).lastWith true naiveL.h naiveL.H
          (naiveL.B.take 2)).1.k = V.k + 42 + 18 * j := by
  obtain ⟨-, -, h0⟩ := LoopSeg.stepAt_k true naive.fn_0.b_0.label SymSelect.entry
    [(naive.fn_0.b_2.label, pre.obls, pre)] naiveL V j 0
  obtain ⟨-, -, h2⟩ := LoopSeg.stepAt_k true naive.fn_0.b_0.label SymSelect.entry
    [(naive.fn_0.b_2.label, pre.obls, pre)] naiveL V j 2
  have e1 : pathLen SymSelect.entry [(naive.fn_0.b_2.label, pre.obls, pre)] = 38 := by
    decide +kernel
  have e2 : pathLen naiveL.H naiveL.B = 17 := by decide +kernel
  have e3 : pathOff naiveL.H naiveL.B 2 = 3 := by decide +kernel
  simp only [LoopSeg.stepAt, e1, e2, e3, pathOff] at h0 h2
  refine ⟨?_, by omega⟩
  show (((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[j]
    (Valuation.roundWith true naive.fn_0.b_0.label SymSelect.entry
      [(naive.fn_0.b_2.label, pre.obls, pre)] V)).lastWith true naiveL.h naiveL.H
      (naiveL.B.take 0)).1.k = _
  omega

/-! ## Two counting loops that store -/

open MojoProofTest.SymLoop

/-- The registers `cnt2`'s loops keep (`LoopSeg.kept`): the bound `%10` and the pointer `%11` of
the first loop, `%10` and the pointer `%16` of the second. The counters, set by their `phi`s,
and the body's registers are not kept. -/
theorem cnt2_kept : loop1.kept cnt2 = [10, 11] ∧ loop2.kept cnt2 = [10, 16] := by
  decide +kernel

/-- **The load-only check refuses a loop that stores**: `cnt2`'s first loop stores through `%12`,
so `LoopSeg.loadsFrom` is false with its kept pointer `%11`, the twin of `naive_loads`. -/
theorem cnt2_stores : loop1.loadsFrom cnt2 [11] = false := by
  decide +kernel

/-- The step counts of `cnt2`'s entry block and first loop (`LoopSeg.steps_k`), for all
valuations `V`, `W` and every `j`: the entry block `br` adds 1 step, each round 6 (the header's
`icmp` and branch, the body's three statements and branch), and the body is entered 2 steps
after the head. -/
theorem cnt2_steps (V W : Valuation) (j : Nat) :
    (Valuation.roundWith false 0 cntE [] V).ctx = V.ctx ∧
      (Valuation.roundWith false 0 cntE [] V).fn = V.fn ∧
      (Valuation.roundWith false 0 cntE [] V).k = V.k + 1 ∧
      ((Valuation.roundWith false loop1.h loop1.H loop1.B)^[j] W).ctx = W.ctx ∧
      ((Valuation.roundWith false loop1.h loop1.H loop1.B)^[j] W).fn = W.fn ∧
      ((Valuation.roundWith false loop1.h loop1.H loop1.B)^[j] W).k = W.k + 6 * j ∧
      (W.lastWith false loop1.h loop1.H loop1.B).1.ctx = W.ctx ∧
      (W.lastWith false loop1.h loop1.H loop1.B).1.k = W.k + 2 :=
  LoopSeg.steps_k false 0 cntE [] loop1 (by decide +kernel) (by decide +kernel)
    (by decide +kernel) V W j

end MojoProofTest.LoopFacts
