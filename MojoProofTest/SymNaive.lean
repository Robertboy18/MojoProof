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

* `naive_refusals`: the checker's verdict (`refusal`, from `summarize`'s start state
  `SState.start`, the statement at which `summarize` stops) on every block from its position after
  its `phi`s: it accepts every block but `%52`, refused at its `fmul contract` (statement 12).
  `%45`'s `br` passes the float constant `0.0` to `%48`, which is the block's node 0
  (`SNode.flit`).
* `naive_refusalsC`: the checker with `fmul contract` (`summarizeC`) accepts every block.
* `skip`, `body`, `skip_body_covers`: the summaries of `%44` and `%50`, the blocks of no
  statement that branch to `%69` and to `%52`; the checker accepts both, and `%69`'s summary is
  `Kernels.vadd.b3` (`ret void` alone).

* `trip1_covers`, `trip1_latch`, `trip1_round`: `%46 → %50`, accepted by the path checker with
  `phi`s, then the latch `%52`, accepted by `coversC` (`Block.sound_pathC`), and its branch back
  into `%46` after its `phi`s (`Ends.edgeC`): one trip of the loop, from the head to the head;
  the path checker refuses the path through the latch.

* `naiveL`, `naiveL_covers`: the loop `%46 → %50 → %52` as a loop (`LoopSeg`) with the path out
  `%51 → %67 → %69`; the path checker with `fmul contract` accepts its round
  (`LoopSeg.coversRoundWith true`), the one without refuses it.
* `pre_edge`: the premises of the edge `%45 → %46` (`EdgeWith`, the preheader `pre` into the
  loop head at position 2) hold at every valuation of `naive`'s function, with or without
  `fmul contract`; the float constant `0.0` of node 0 is evaluated once by `decide +kernel`.
* `frameL`, `loop_rounds`, `loop_regs`, `loop_two`: at one thread at `%46`'s position 2 with the
  counter `%47 = 0`, the accumulator `%48 = 0.0`, the bound `%16 = 2`, the row and column offsets
  `%26 = %37 = 0` and the inputs of `mem0`, two rounds of the loop (`Block.sound_loop` with
  `contract = true`), back to `%46`'s position 2 with `%47 = 2` and `%48 = 1.0`
  (`1 * 0.5 + 2 * 0.25`).

The other blocks' tests: `%6` (`entry_covers`, MojoProofTest/SymSelect.lean); `%46`, `%51`,
`%67`, and `%45` (`trip0_covers`, `pre_covers`, `trip0_twins`, MojoProofTest/SymPhi.lean); `%52`
(`naive_latch_refusal`, MojoProofTest/SymLoop.lean, and `latch_covers`,
MojoProofTest/SymContract.lean).

Each result covers the program and blocks it names, not all programs; `loop_two` covers one
thread, one memory and the trip count 2.
-/

namespace MojoProofTest.SymNaive

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi MojoProofTest.SymRun

/-- **The verdict on every block**: from the position after its `phi`s (`phiCount`) and
`summarize`'s start state (`SState.start`: the block's float constants as nodes), the block
checker accepts (`refusal` is `none`) every block but `%52`, which it refuses at statement 12
(`%65 = fmul contract`). -/
theorem naive_refusals :
    naive.fn_0.blocks.toList.map (fun b =>
      (b.label, refusal naive.prog naive.fn_0 b (phiCount naive.fn_0 b.label))) =
    [(naive.fn_0.b_0.label, none), (naive.fn_0.b_1.label, none), (naive.fn_0.b_2.label, none),
      (naive.fn_0.b_3.label, none), (naive.fn_0.b_4.label, none), (naive.fn_0.b_5.label, none),
      (naive.fn_0.b_6.label, some 12), (naive.fn_0.b_7.label, none),
      (naive.fn_0.b_8.label, none)] := by
  decide +kernel

/-- **The verdict with `fmul contract`**: from the position after its `phi`s, `summarizeC` gives
a summary of every block. -/
theorem naive_refusalsC :
    naive.fn_0.blocks.toList.map (fun b => (b.label,
      (summarizeC naive.prog naive.fn_0 b.label (phiCount naive.fn_0 b.label)).isSome)) =
    [(naive.fn_0.b_0.label, true), (naive.fn_0.b_1.label, true), (naive.fn_0.b_2.label, true),
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

/-- **A trip up to the latch, and its twin**: the path checker (`coversPathWith false`) accepts
`%46 → %50` from `%46`'s position 2, and refuses `%46 → %50 → %52` (the checker without
`fmul contract` refuses the latch `%52`, `latch_refused`). -/
theorem trip1_covers :
    coversPathWith false naive.prog naive.fn_0 2
      [(naive.fn_0.b_3.label, hdr.obls, hdr), (naive.fn_0.b_4.label, body.obls, body)] = true ∧
    coversPathWith false naive.prog naive.fn_0 2
      [(naive.fn_0.b_3.label, hdr.obls, hdr), (naive.fn_0.b_4.label, body.obls, body),
        (naive.fn_0.b_6.label, SymContract.latch.obls, SymContract.latch)] = false := by
  decide +kernel

/-- **A trip of the loop to the latch's end** (`Block.sound_pathC`): for every context `c` of
`naive`'s program and thread whose innermost frame `f` (above frames `rest`) is at the loop head
`%46`'s position 2, with memory `m`: if the premises of `%46 → %50` hold (`WalkWith false`:
among them, the head branches to `%50`) and the latch's obligations hold at its entry valuation,
the thread's steps run `%46`, `%50` and the latch `%52`, which ends with the table's
`fmul contract` operands (`EndsC`). -/
theorem trip1_latch {c : Ctx} (hP : c.prog = naive.prog) {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = naive.fn_0)
    (hl : f.label = naive.fn_0.b_3.label) (hp : f.pc = 2)
    (hW : WalkWith false (Valuation.entry c t.k m f)
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
    (hW : WalkWith false (Valuation.entry c t.k m f)
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

/-- The loop `%46 → %50 → %52` of `naive`: header `%46` from position 2 (after its `phi`s) with
summary `hdr`, then `%50` (`body`) and the latch `%52` (`SymContract.latch`, with
`fmul contract`), whose branch goes back to `%46`; the path out is `trip0` (`%51 → %67 → %69`),
and no loop is nested in it. -/
def naiveL : LoopSeg :=
  ⟨naive.fn_0.b_3.label, 2, hdr.obls, hdr,
    [(naive.fn_0.b_4.label, body.obls, body),
      (naive.fn_0.b_6.label, SymContract.latch.obls, SymContract.latch)], trip0, []⟩

/-- **The loop's round with and without `fmul contract`**: the path checker with the flag
(`LoopSeg.coversRoundWith true`) accepts `naiveL`'s round `%46 → %50 → %52` from position 2, and
accepts it as the loop path of `Block.sound_loop` (`coversPathWith true`); the checker without
it (`LoopSeg.coversRound`) refuses it, at the latch's `fmul contract`. -/
theorem naiveL_covers :
    naiveL.coversRoundWith true naive.prog naive.fn_0 = true ∧
      coversPathWith true naive.prog naive.fn_0 2
        ((naiveL.h, naiveL.dh, naiveL.H) :: naiveL.B) = true ∧
      naiveL.coversRound naive.prog naive.fn_0 = false := by
  decide +kernel

/-- **The edge `%45 → %46` at every valuation**: for every flag `contract` and every valuation
`V` of `naive`'s function (`V.fn = naive.fn_0`), the premises of the preheader `%45` (`pre`)
and of its edge into the loop head hold (`EdgeWith contract`): its obligations (the word 0 for
`%47`, node 0 for `%48`, no effect) hold at `V`, its exit goes to `%46` (`naiveL.h`), at
position 2 (`naiveL.p`, after the two `phi`s). Node 0 is the float constant `0.0`, so its
obligation does not depend on `V`: `decide +kernel` evaluates the constant (`floatLit`) once.
This covers every frame of every thread that reaches `%45`; a path into `%45` adds its own
premises before these (`EdgeWith` of a longer path unfolds into its first block's and this
one's). -/
theorem pre_edge (contract : Bool) (V : Valuation) (hfn : V.fn = naive.fn_0) :
    EdgeWith contract naiveL.h naiveL.p V naive.fn_0.b_2.label pre.obls pre [] := by
  obtain ⟨hn, ho, -⟩ := pre_covers
  have hx : pre.exit = .phi (.int 1 1) naive.fn_0.b_3.label naive.fn_0.b_3.label := by
    decide +kernel
  have h0 : (floatLit .float (.dec false "0" "000000" 0)).isOk = true := by decide +kernel
  refine ⟨fun d hd => ?_, ?_, ?_⟩
  · rw [ho] at hd
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hd
    rcases hd with rfl | rfl | rfl
    · exact ⟨_, rfl⟩
    · rw [hn]
      show ∃ v, floatLit .float (.dec false "0" "000000" 0) = .ok v
      revert h0
      cases floatLit .float (.dec false "0" "000000" 0) with
      | ok v => exact fun _ => ⟨v, rfl⟩
      | error e => exact fun h => absurd h (by simp [Except.isOk, Except.toBool])
    · exact ⟨V.mem, rfl⟩
  · show pre.exit.dest V (vals V pre.nodes) = some naiveL.h
    rw [hx]
    rfl
  · show Exit.pc V.fn naive.fn_0.b_3.label pre.exit = 2
    rw [hx, hfn]
    decide +kernel

/-- A frame of `naive` at the loop head `%46`'s position 2: counter `%47 = 0`, accumulator
`%48 = 0.0`, bound `%16 = 2`, row offset `%26 = 0`, column offset `%37 = 0`, the inputs `%11` and
`%12` at blocks 1 and 2 of `mem0` and the output `%40` at block 3; no `fmul contract` operands,
no `alloca` blocks, no caller register. -/
def frameL : Frame :=
  ⟨naive.fn_0, naive.fn_0.b_3.label, 2,
    fun r => if r = idx "47" then some (.bits 64 0)
      else if r = idx "48" then some (.bits 32 0)
      else if r = idx "16" then some (.bits 64 2)
      else if r = idx "26" then some (.bits 32 0)
      else if r = idx "37" then some (.bits 32 0)
      else if r = idx "11" then some (.ptr ⟨1, 0⟩)
      else if r = idx "12" then some (.ptr ⟨2, 0⟩)
      else if r = idx "40" then some (.ptr ⟨3, 0⟩)
      else none,
    fun _ => none, [], none⟩

/-- **The premises of two rounds**: under `ctxN` on `mem0`, from `frameL`'s entry valuation, the
premises of rounds 0 and 1 of `naiveL` with `fmul contract` hold (`RoundWith true` at the
iterates of `Valuation.roundWith true`): the header branches to `%50`, the latch's loads are in
bounds, and the latch goes back to `%46` at position 2. -/
theorem loop_rounds : ∀ i < 2, RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B
    ((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[i]
      (Valuation.entry ctxN 0 mem0 frameL)) := by
  decide +kernel

/-- **The registers after two rounds**: at the second iterate of `Valuation.roundWith true` from
`frameL`'s entry valuation, the counter `%47` is 2 and the accumulator `%48` holds the binary32
word of 1.0, `1 * 0.5 + 2 * 0.25` from the first two cells of `inA` and `inB`. -/
theorem loop_regs :
    ((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[2]
      (Valuation.entry ctxN 0 mem0 frameL)).regs (idx "47") = some (.bits 64 2) ∧
    ((Valuation.roundWith true naiveL.h naiveL.H naiveL.B)^[2]
      (Valuation.entry ctxN 0 mem0 frameL)).regs (idx "48") =
        some (.bits 32 (BitVec.ofNat 32 0x3f800000)) :=
  ⟨rfl, rfl⟩

/-- **Two rounds of the loop with `fmul contract`** (`Block.sound_loop` with `contract = true`,
`naiveL_covers`, `loop_rounds`, `loop_regs`): under `ctxN` on `mem0`, the thread of the one frame
`frameL` steps through `%46 → %50 → %52` twice, back to a frame of `naive`'s function at `%46`'s
position 2 with the counter `%47 = 2` and the accumulator `%48 = 1.0`. -/
theorem loop_two : ∃ t' m' f', Steps ctxN ⟨[frameL], 0⟩ mem0 t' m' ∧ t'.frames = [f'] ∧
    f'.fn = naive.fn_0 ∧ f'.label = naive.fn_0.b_3.label ∧ f'.pc = 2 ∧
    f'.regs (idx "47") = some (.bits 64 2) ∧
    f'.regs (idx "48") = some (.bits 32 (BitVec.ofNat 32 0x3f800000)) := by
  obtain ⟨t', m', f', hS, ht', hfn, hl, hp, -, -, hV⟩ :=
    Block.sound_loop (contract := true) (c := ctxN) (t := ⟨[frameL], 0⟩) (m := mem0)
      (f := frameL) rfl naiveL_covers.2.1 2 rfl rfl rfl rfl loop_rounds
  have hr := congrArg Valuation.regs hV
  exact ⟨t', m', f', hS, ht', hfn, hl, hp, (congrFun hr _).trans loop_regs.1,
    (congrFun hr _).trans loop_regs.2⟩

end MojoProofTest.SymNaive
