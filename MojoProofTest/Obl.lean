import MojoProof.Sym.Obl
import MojoProof.Kernels.Vadd
import MojoProofTest.SymLoop

/-!
# Tests of the tactic mojo_obl: `vector_addition`'s walks on every launch

`vadd_walk_launch`, with the no-wrap premises `hFa hFb hFo`: for every valid one-dimensional
launch, every alignment `al` that `4` divides, buffers `a`, `b`, `out` and length `n < 2 ^ 31`,
every thread `k`, and every context, memory and frame with the listed facts, the thread walks the
path the index selects (`%4 → %21 → %31` when `k < n`, `%4 → %30 → %31` otherwise): each block's
obligations hold (every node evaluates, the condition is a word, the loads and the store run) and
each exit goes to the next block.

`vadd_walk_launch_open` is the twin: with `k < n` behind an irreducible definition, mojo_obl
cannot decide `%4`'s branch and leaves its exit open, as logged; unfolding the definition closes
it.

`hand_walk` and the last `example` run mojo_obl on two hand-written summaries and on the empty
path: an unsigned comparison of two registers, a register the first block does not set (read after
it), a branch condition that is a word but not a comparison, and a walk of no blocks (the
statement of the library's `Walk.nil'`, so an `example`, not a copy of it).

`cnt_paths` runs mojo_obl on the counting loop `cnt` of MojoProofTest/SymLoop.lean, whose edges
go into blocks with `phi`s (`Exit.phi`): for every trip count `n < 4` on `outC` (the runs of
`cnt_run_outC`), the entry edge (`Edge`), every round below `n` (`Round`) and the path out of the
loop (`WalkI`). `cnt_entry` is the entry edge for every context, step count, memory and frame of
`cnt`; `cnt_entry_open` is its twin, with `f.fn = cnt` behind an irreducible definition, so the
position the edge enters the header at is left open, as logged.

`cnt_rounds` is the loop's rounds for every bound: for every `n ≤ 2 ^ 60` and every round
`i < n` (no literal bound, so mojo_obl proves it for an arbitrary `i`, one proof for every `n`),
every valuation that meets the invariant `invB` (one conjunction, which mojo_obl splits) meets the
round's premises, the store through address space 1 included. `cnt_rounds_open` is its twin, with
the bound on the block's address behind an irreducible definition: the store is left open, as
logged (the `getelementptr` is some value, a pointer or poison, with no bound).

`cnt_rounds_struct` is `cnt_rounds` with the invariant a hypothesis of the context, a structure
of propositions (`InvS`) whose fields and conjuncts mojo_obl reads (`Obl.parts`);
`cnt_rounds_struct_open` is its twin, the field on the block's address behind `Room`, its store
left open, as logged. `cnt_have` names two registers after a round in one `obl_have`; the last
`example` is `obl_have`'s refusal of a term that is no register, memory or node value.
-/

namespace MojoProofTest.Obl

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym TorchLean
  FloatLib.Floats.Formats.BinaryInterchange

/-- **`vector_addition` walks the path its index selects** for every valid 1-D launch, thread
`k`, length `n < 2 ^ 31` and memory whose buffers `a`, `b`, `out` (of `n` floats, aligned to `al`,
`4 ∣ al`, not wrapping `2 ^ 64`) hold the inputs: path 0 when `k < n`, path 1 otherwise. -/
theorem vadd_walk_launch :
    ∀ (L : Launch), L.Valid → L.grid .y = 1 ∧ L.grid .z = 1 → L.block .y = 1 ∧ L.block .z = 1 →
    ∀ (al : Nat), 4 ∣ al →
    ∀ (a b out n N : Nat) (x y : Tensor (Model FloatTy.float.fmt) [N]),
    a ≠ b ∧ a ≠ out ∧ b ≠ out → n ≤ N → n < 2 ^ 31 →
    ∀ (k : Nat), k < volume L.grid * volume L.block →
    ∀ (c : Ctx), c.prog = Kernels.vadd.prog → c.env = L.env k →
      c.who = ⟨k, k / volume L.block⟩ →
    ∀ (m : Mem) (f : Frame), f.fn = Kernels.vadd.fn_0 →
    ∀ (p0 p1 p2 : Nat),
      f.regs 0 = some (.ptr ⟨p0, 0⟩) → f.regs 1 = some (.ptr ⟨p1, 0⟩) →
      f.regs 2 = some (.ptr ⟨p2, 0⟩) → f.regs 3 = some (.bits 32 (BitVec.ofNat 32 n)) →
      m.load Kernels.vadd.prog.layout c.who 0
        (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]]) ⟨p0, 0⟩ (some 8) =
        .ok (.agg [.ptr ⟨a, 0⟩, .agg [.agg [.agg []], .agg [.agg []]]]) →
      m.load Kernels.vadd.prog.layout c.who 0
        (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]]) ⟨p1, 0⟩ (some 8) =
        .ok (.agg [.ptr ⟨b, 0⟩, .agg [.agg [.agg []], .agg [.agg []]]]) →
      m.load Kernels.vadd.prog.layout c.who 0
        (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]]) ⟨p2, 0⟩ (some 8) =
        .ok (.agg [.ptr ⟨out, 0⟩, .agg [.agg [.agg []], .agg [.agg []]]]) →
      m.Buffer a (n * Kernels.vadd.prog.layout.size (.fp .float)) al false →
      m.Buffer b (n * Kernels.vadd.prog.layout.size (.fp .float)) al false →
      m.Buffer out (n * Kernels.vadd.prog.layout.size (.fp .float)) al true →
      m.Holds Kernels.vadd.prog.layout a (.fp .float) (Val.ofFloat .float)
        (rowMajor Kernels.vadd.prog.layout (.fp .float) 0) x →
      m.Holds Kernels.vadd.prog.layout b (.fp .float) (Val.ofFloat .float)
        (rowMajor Kernels.vadd.prog.layout (.fp .float) 0) y →
      m.Fits Kernels.vadd.prog.layout a (n * Kernels.vadd.prog.layout.size (.fp .float)) →
      m.Fits Kernels.vadd.prog.layout b (n * Kernels.vadd.prog.layout.size (.fp .float)) →
      m.Fits Kernels.vadd.prog.layout out (n * Kernels.vadd.prog.layout.size (.fp .float)) →
      (k < n → Walk (Valuation.entry c 0 m f) (Kernels.vadd.paths.getD 0 [])) ∧
      (¬ k < n → Walk (Valuation.entry c 0 m f) (Kernels.vadd.paths.getD 1 [])) := by
  intro L hL hg hb al hal a b out n N x y hne hnN h31 k hk c hcp hce hcw m f hf p0 p1 p2 hr0 hr1
    hr2 hr3 hv0 hv1 hv2 hA hB hO hx hy hFa hFb hFo
  refine ⟨fun hkn => ?walk_in, fun hkn => ?walk_out⟩
  · mojo_obl
  · mojo_obl

/-- `k < n`, behind an irreducible definition. -/
@[irreducible] def Below (k n : Nat) : Prop := k < n

/--
info: mojo_obl: open goal
  Exit.target (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) Kernels.vadd.b0.nodes)
    Kernels.vadd.b0.exit = some 22
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `vadd_walk_launch`'s second goal**: with `¬ k < n` stated as `¬ Below k n`,
mojo_obl finds no fact deciding block `%4`'s branch, so it leaves the exit `= some 22` open (and
proves everything else); `unfold Below` then lets it close that goal. -/
theorem vadd_walk_launch_open (L : Launch) (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) (n : Nat) (h31 : n < 2 ^ 31) (k : Nat)
    (hk : k < volume L.grid * volume L.block) (c : Ctx) (hcp : c.prog = Kernels.vadd.prog)
    (hce : c.env = L.env k) (m : Mem) (f : Frame) (hf : f.fn = Kernels.vadd.fn_0)
    (p0 p1 p2 a b out : Nat)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩)) (hr1 : f.regs 1 = some (.ptr ⟨p1, 0⟩))
    (hr2 : f.regs 2 = some (.ptr ⟨p2, 0⟩)) (hr3 : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 n)))
    (hv0 : m.load Kernels.vadd.prog.layout c.who 0
      (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]]) ⟨p0, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨a, 0⟩, .agg [.agg [.agg []], .agg [.agg []]]]))
    (hv1 : m.load Kernels.vadd.prog.layout c.who 0
      (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]]) ⟨p1, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨b, 0⟩, .agg [.agg [.agg []], .agg [.agg []]]]))
    (hv2 : m.load Kernels.vadd.prog.layout c.who 0
      (.struct [.ptr 0, .struct [.struct [.struct []], .struct [.struct []]]]) ⟨p2, 0⟩ (some 8) =
      .ok (.agg [.ptr ⟨out, 0⟩, .agg [.agg [.agg []], .agg [.agg []]]]))
    (hkn : ¬ Below k n) :
    Walk (Valuation.entry c 0 m f) (Kernels.vadd.paths.getD 1 []) := by
  mojo_obl
  unfold Below at hkn
  mojo_obl

/-- A block comparing registers `0` and `1` unsigned (`icmp ult`), setting register `5` to the
result and branching on it to `1` or `2`. -/
def hand0 : Summary :=
  { nodes := [.icmp .ult 32 (.reg 0) (.reg 1)], regs := [(5, .node 0)], effs := [],
    obls := [.bool (.node 0), .ok (.node 0)], exit := .cond (.node 0) 1 2, len := 1 }

/-- A block that compares registers `0` and `1` again (neither set by `hand0`) and needs
registers `2` and `5` to be words. -/
def hand1 : Summary :=
  { nodes := [.icmp .ult 32 (.reg 0) (.reg 1)], regs := [], effs := [],
    obls := [.ok (.node 0), .bool (.reg 2), .bool (.reg 5), .mem []], exit := .ret, len := 1 }

/-- **mojo_obl on hand-written summaries**: for every context, memory and frame whose registers
`0`, `1` hold the 32-bit words of `x < y` and whose register `2` is a 1-bit word, the path
`hand0 → hand1` walks (`icmp ult` by `SNode.eval_icmp_ult_ofNat`, registers through a block by
`Valuation.after_regs_none`, a word condition by `Cond.holds_bool`). -/
theorem hand_walk (c : Ctx) (m : Mem) (f : Frame) (x y : Nat) (b : BitVec 1)
    (hx : x < 2 ^ 32) (hy : y < 2 ^ 32) (hxy : x < y)
    (h0 : f.regs 0 = some (.bits 32 (BitVec.ofNat 32 x)))
    (h1 : f.regs 1 = some (.bits 32 (BitVec.ofNat 32 y))) (h2 : f.regs 2 = some (.bits 1 b)) :
    Walk (Valuation.entry c 0 m f) [(0, hand0.obls, hand0), (1, hand1.obls, hand1)] := by
  mojo_obl

/-- The empty path walks from every valuation (the statement of `Walk.nil'`). -/
example (V : Valuation) : Walk V [] := by
  mojo_obl

section Loop

open MojoProofTest.SymLoop

/-- **The counting loop's premises by mojo_obl**, for every trip count `n < 4` on `outC` (the runs
of `cnt_run_outC`): from `start n` the entry block's edge goes to the header `1` at position 1
(`Edge`); every round `i < n` from the header's entry valuation after `i` rounds walks the loop
path `1 → 2` and its back edge goes to the header at position 1 (`Round`); and the path out of
the loop `1 → 3` walks from the header after `n` rounds (`WalkI`). mojo_obl gets each `phi`'s
value from `enter`'s lemma (`Valuation.into_regs_phi`), each branch's direction from its
condition (`Exit.dest_phi_true`, `Exit.dest_of_target`), and the body's address and store, to a
block that no `Mem.Buffer` hypothesis describes, by the kernel's evaluation (the valuation is
closed). -/
theorem cnt_paths : ∀ n : Nat, n < 4 →
    Edge 1 1 (start n) 0 cntE.obls cntE [] ∧
    (∀ i < n, Round 1 1 cntH.obls cntH bodyC ((Valuation.round 1 cntH bodyC)^[i] (hdrC n))) ∧
    WalkI ((Valuation.round 1 cntH bodyC)^[n] (hdrC n)) ((1, cntH.obls, cntH) :: exitC) := by
  mojo_obl

/-- **The counting loop's entry edge for every frame of `cnt`**: for every context, step count,
memory and frame running `cnt`, the entry block's obligations hold and its edge goes to the
header `1` at position 1, after its `phi` (`Edge`). -/
theorem cnt_entry (c : Ctx) (k : Nat) (m : Mem) (f : Frame) (hf : f.fn = cnt) :
    Edge 1 1 (Valuation.entry c k m f) 0 cntE.obls cntE [] := by
  mojo_obl

/-- `f.fn = cnt`, irreducible, so that mojo_obl does not find the function. -/
@[irreducible] def IsCnt (f : Frame) : Prop := f.fn = cnt

/--
info: mojo_obl: open goal
  Exit.pc (Valuation.entry c k m f).fn 1 cntE.exit = 1
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `cnt_entry`**: with `f.fn = cnt` stated as `IsCnt f`, mojo_obl does not know
the function, so it leaves open the position the edge enters the header at (`Exit.pc`, the
number of the header's `phi`s), as logged, and proves the rest; `Exit.pc_of_fn` closes it from the
unfolded hypothesis. -/
theorem cnt_entry_open (c : Ctx) (k : Nat) (m : Mem) (f : Frame) (hf : IsCnt f) :
    Edge 1 1 (Valuation.entry c k m f) 0 cntE.obls cntE [] := by
  mojo_obl
  unfold IsCnt at hf
  exact Exit.pc_of_fn hf rfl

/-- The facts of round `i` of the counting loop for the bound `n` and the block `b`, one
conjunction: valuation `W` is in a context of `cntP` and in `cnt`, `%i = i`, `%n = n`, `%p` is at
offset 0 of `b`, `b` is a writable buffer of `n` cells of `i64` (`8 n` bytes) aligned to 8, and
its address plus its size is at most `2 ^ 64`, 2 to the width of the pointers of address space 1
(`cntP_ptr`). -/
def invB (n b i : Nat) (W : Valuation) : Prop :=
  W.ctx.prog = cntP ∧ W.fn = cnt ∧ W.regs 4 = some (.bits 64 (BitVec.ofNat 64 i)) ∧
    W.regs 7 = some (.bits 64 (BitVec.ofNat 64 n)) ∧ W.regs 8 = some (.ptr ⟨b, 0⟩) ∧
    W.mem.Buffer b (8 * n) 8 true ∧
    ∃ blk, W.mem.blocks b = some blk ∧ blk.addr + 8 * n ≤ 2 ^ (cntP.layout.ptr 1).1

/-- **The counting loop's rounds for every bound**, by mojo_obl with no literal bound: for every
bound `n ≤ 2 ^ 60`, block `b`, round `i < n` and valuation `W` of `invB n b i`, the round's
premises hold at `W` (`Round`: the header's comparison `i < n` is true, the body's increment,
address and store of cell `i` run, its edge goes to the header at position 1). mojo_obl proves
`∀ i < n` for an arbitrary `i` with `i < n` as a hypothesis, and finds the registers, the
function, the program and the buffer among `invB`'s conjuncts; the address of cell `i` and the
store, through pointers of address space 1, by `gep_buffer` and `store_buffer` in that space. -/
theorem cnt_rounds : ∀ n b : Nat, n ≤ 2 ^ 60 → ∀ i < n, ∀ W : Valuation, invB n b i W →
    Round 1 1 cntH.obls cntH bodyC W := by
  mojo_obl

/-- The bound on the address of block `b` of memory `m` in `invB`, irreducible, so that mojo_obl
does not find it. -/
@[irreducible] def Room (m : Mem) (b n : Nat) : Prop :=
  ∃ blk, m.blocks b = some blk ∧ blk.addr + 8 * n ≤ 2 ^ (cntP.layout.ptr 1).1

/-- `invB` with the bound on the block's address stated as `Room`. -/
def invR (n b i : Nat) (W : Valuation) : Prop :=
  W.ctx.prog = cntP ∧ W.fn = cnt ∧ W.regs 4 = some (.bits 64 (BitVec.ofNat 64 i)) ∧
    W.regs 7 = some (.bits 64 (BitVec.ofNat 64 n)) ∧ W.regs 8 = some (.ptr ⟨b, 0⟩) ∧
    W.mem.Buffer b (8 * n) 8 true ∧ Room W.mem b n

/--
info: mojo_obl: open goal
  Cond.Holds (W.into 1 cntH) (vals (W.into 1 cntH) cntB.nodes)
    (Cond.mem [SEff.store 2 2 (SVal.reg 4) (SVal.node 1)])
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `cnt_rounds`**: with the bound on the block's address behind the irreducible
`Room`, mojo_obl finds no no-wrap fact for the body's pointer, so it leaves open the obligation
that needs the address of cell `i` (the store), as logged, and proves the rest, the value of the
`getelementptr` as some value, a pointer or poison (`gep_buffer_ok`); unfolding `Room` lets it
close the store. -/
theorem cnt_rounds_open : ∀ n b : Nat, n ≤ 2 ^ 60 → ∀ i < n, ∀ W : Valuation, invR n b i W →
    Round 1 1 cntH.obls cntH bodyC W := by
  mojo_obl
  unfold Room at *
  mojo_obl

/-- The facts of `invB` as a structure of propositions, one field each and the registers one
conjunction: valuation `W` is in a context of `cntP` and in `cnt`, `%i = i`, `%n = n`, `%p` is at
offset 0 of `b`, `b` is a writable buffer of `n` cells of `i64` aligned to 8, and its address plus
its size is at most `2 ^ 64`. -/
structure InvS (n b i : Nat) (W : Valuation) : Prop where
  /-- Builds `InvS` from its fields. -/
  mk ::
  /-- `W` is in a context of `cntP`. -/
  prog : W.ctx.prog = cntP
  /-- `W` is in `cnt`. -/
  fn : W.fn = cnt
  /-- `%i = i`, `%n = n` and `%p` is at offset 0 of `b`. -/
  regs : W.regs 4 = some (.bits 64 (BitVec.ofNat 64 i)) ∧
    W.regs 7 = some (.bits 64 (BitVec.ofNat 64 n)) ∧ W.regs 8 = some (.ptr ⟨b, 0⟩)
  /-- `b` is a writable buffer of `n` cells of `i64` aligned to 8. -/
  buf : W.mem.Buffer b (8 * n) 8 true
  /-- The block's address plus its size is at most `2 ^ 64`. -/
  room : ∃ blk, W.mem.blocks b = some blk ∧ blk.addr + 8 * n ≤ 2 ^ (cntP.layout.ptr 1).1

/-- **The counting loop's rounds from a structure in the context**, by mojo_obl: for every bound
`n ≤ 2 ^ 60`, block `b`, round `i < n` and valuation `W` with a hypothesis `h : InvS n b i W`,
the round's premises hold at `W` (`Round`); mojo_obl finds the program, the function, the buffer
and its room among the fields of `h` and the registers among the conjuncts of its field `regs`
(`Obl.parts`). -/
theorem cnt_rounds_struct (n b i : Nat) (hn : n ≤ 2 ^ 60) (hi : i < n) (W : Valuation)
    (h : InvS n b i W) : Round 1 1 cntH.obls cntH bodyC W := by
  mojo_obl

/-- `InvS` with the bound on the block's address stated as `Room`. -/
structure InvSR (n b i : Nat) (W : Valuation) : Prop where
  /-- Builds `InvSR` from its fields. -/
  mk ::
  /-- `W` is in a context of `cntP`. -/
  prog : W.ctx.prog = cntP
  /-- `W` is in `cnt`. -/
  fn : W.fn = cnt
  /-- `%i = i`, `%n = n` and `%p` is at offset 0 of `b`. -/
  regs : W.regs 4 = some (.bits 64 (BitVec.ofNat 64 i)) ∧
    W.regs 7 = some (.bits 64 (BitVec.ofNat 64 n)) ∧ W.regs 8 = some (.ptr ⟨b, 0⟩)
  /-- `b` is a writable buffer of `n` cells of `i64` aligned to 8. -/
  buf : W.mem.Buffer b (8 * n) 8 true
  /-- The block's address plus its size is at most `2 ^ 64`, irreducible. -/
  room : Room W.mem b n

/--
info: mojo_obl: open goal
  Cond.Holds (W.into 1 cntH) (vals (W.into 1 cntH) cntB.nodes)
    (Cond.mem [SEff.store 2 2 (SVal.reg 4) (SVal.node 1)])
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `cnt_rounds_struct`**: with the field `room` behind the irreducible `Room`,
mojo_obl finds no no-wrap fact for the body's pointer among the parts of `h`, so it leaves the
store open, as logged, and proves the rest. The goal left open has the hypotheses of the call,
not the parts of `h`; the field taken by `have` (whose goal carries an annotation mojo_obl looks
through) and unfolded lets it close the store. -/
theorem cnt_rounds_struct_open (n b i : Nat) (hn : n ≤ 2 ^ 60) (hi : i < n) (W : Valuation)
    (h : InvSR n b i W) : Round 1 1 cntH.obls cntH bodyC W := by
  mojo_obl
  have hr := h.room
  unfold Room at hr
  mojo_obl

/-- **Two registers after a round in one `obl_have`**: for every bound `n ≤ 2 ^ 60`, block `b`,
round `i < n` and valuation `W` with `h : InvS n b i W`, the counter `%i` and the bound `%n` have
values after the round `1 → 2`, both from one run of the evaluator on the facts of `h`'s
parts. -/
theorem cnt_have (n b i : Nat) (hn : n ≤ 2 ^ 60) (hi : i < n) (W : Valuation)
    (h : InvS n b i W) : ∃ v w, (Valuation.round 1 cntH bodyC W).regs 4 = some v ∧
      (Valuation.round 1 cntH bodyC W).regs 7 = some w := by
  obl_have h4 : (Valuation.round 1 cntH bodyC W).regs 4,
    h7 : (Valuation.round 1 cntH bodyC W).regs 7
  exact ⟨_, _, h4, h7⟩

end Loop

/-- error: obl_have: not a register, memory or node value
  V.k -/
#guard_msgs in
example (V : Valuation) : V.k = V.k := by
  obl_have h : V.k
  rfl

end MojoProofTest.Obl
