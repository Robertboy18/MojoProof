import MojoProof.Sem.Skeleton
import MojoProofTest.Determinism

/-!
# Instances and twins of T3b's relations

`skel_vals`: two aggregates whose data words differ, inside a vector with a pointer lane and
outside, are related by `Val.Skel`, and two pointers to different blocks, words of two widths, and
a word and `poison` are not.

The instance of `Mem.SkelEq`: `memX 1` and `memX 2`, whose block 1 (4 bytes) has the data byte 1
or 2 at offset 0, are related when block 1 is payload, and not when no block is (`skel_pay`; the
second part is the twin of the premise that the block is payload).

The instance of `Thread.Skel`: `thrX 1` and `thrX 2`, whose one frame has the data word 1 or 2 in
register 0, are related when register 0 is payload, and not when it is not (`skel_thread`).

The instance of `Grid.SkelRel`: `gridX 1` and `gridX 2`, one running thread `thrX 1` or `thrX 2` on
`memX 1` or `memX 2`, are related when register 0 and block 1 are payload. Two threads waiting at
a shuffle whose result is register 0 are related when their exchanged values differ and register 0
is payload; the twins: not when register 0 is not payload (`Thread.payRes`), and not when their
lane operands differ (`Intrinsic.eraseArgs` erases only the exchanged value) (`skel_grid`).

The twins of the two premises of `Layout.decode_erase`: an `i1` from the data byte 2 (not
`Ty.data`), and an `i8` from two bytes (more than `l.stored t`), erased, differ from the values of
the bytes erased (`decode_twins`). The instance of `Mem.load_skel`: the `i8` loads from block 1 of
`memX 1` and `memX 2` give the words 1 and 2, related; its twin: the `i1` loads give a word and
`poison`, not related (`load_skel`). The instance of `Mem.store_skel`: storing the words 5 and 6
to block 1 of `memX 1` and `memX 2` gives related memories when block 1 is payload; its twin, of
the premise that the values are equal when the block is not payload: storing 5 and 6 to `memX 1`
gives memories that are not related when no block is payload (`store_skel`).

The instances of `Mem.alloc_skel` and `Mem.setLive_skel`: an allocation in `memX 1` and `memX 2`
gives related memories and block 2 in both, and setting block 1 dead gives related memories
(`alloc_skel`).

The instance of `evalV_skel`: a `ptrtoint` of register 0 gives one result on two scopes with
related memories, one register 0 and different oracle numbers; its twin: register 1, which
differs, gives two words (`eval_skel`). Why operands are oracle-free: the
`fpext` instruction of a `half` NaN gives two NaN words under two oracle numbers, and the same
`fpext` as a constant expression, which LangRef does not allow, is refused (`fpext_twin`).

The instance of `lanes_skel` with `intCast_skel`: `trunc` of two related vectors gives related
results; its twin: a lane function that makes `poison` of the word 1 gives results that are not
related (`trunc_skel`). The instance of `lanes2_skel`: pairing the lanes of two pairs of related
vectors gives related results; its twin: `oneP` of the first lane gives results that are not
related (`pair_skel`). The instance of `intBin_skel` with `lanes2_skel`: `add` of two pairs of
related vectors, and `shl` of two related vectors by one amount, give related results; the twins
of its premises: `or disjoint` (a flag) of 1 and 2 gives 3 and of 1 and 1 gives `poison`, `sdiv`
of -128 by -1 faults and of 0 by -1 gives 0 (`BinOp.total`), and `shl` of `<1>` by `<1>` and by
`<9>` gives `<2>` and `<poison>` (`BinOp.skelB`), not related (`bin_skel`).

The instances of `icmpV_skel`: `icmp ult` of 1 by 2 on `memX 1` and of 3 by 2 on `memX 2` gives
`true` and `false`, related, and `icmp eq` of a pointer to block 1 with itself on both gives
related results; the twins of its premises: the pointer comparison faults on a memory with no
block 1 and gives `true` on `memX 1`, and `icmp eq` of the `i8` 1 gives `true` with the `i8` 1 and
faults with the `i16` 1 (`icmp_skel`). The instances of `floatBin_skel`, `fcmpV_skel` and
`fnegV_skel`: `fadd` of a `half` NaN and 0 under two oracle numbers gives two NaN words, related,
and `fcmp oeq` and `fneg` of 0 and of 1 give related results; the twins of their premises that the
flags have no `nnan` and no `ninf`: with `nnan` a NaN operand, and with `ninf` an infinite one,
gives `poison`, and 0 a word (`float_skel`).

The instance of `selectV_skel`: `select` on `<true, false>` of two pairs of related vectors gives
related results; the twin of its premise that the two conditions are one: `select` of the pointers
to blocks 1 and 2 on `true` and on `false` gives results that are not related (`select_skel`). The
instances of `extractE_skel`, `insertE_skel`, `shuffleV_skel`, `extractV_skel` and `insertV_skel`:
`extractelement` and `insertelement` at 0, `shufflevector` by `<1, 0>`, and `extractvalue` and
`insertvalue` at `[0]` of related vectors and aggregates, and related elements, give related
results; the twins of their premises that the two indices, masks or index lists are one: at two
indices, by two masks and at two index lists the results are not related (`elem_skel`,
`shuffle_skel`, `value_skel`). The instances of `castV_skel`: `fpext` of a `half` NaN under two
oracle numbers, `bitcast` of two related vectors to `i16`, and `ptrtoint` of a pointer to block 1
on `memX 1` and `memX 2` give related results; the twin of its premise that the memories are
related: `ptrtoint` faults on a memory with no block 1 and gives a word on `memX 1`
(`cast_skel`). The instance of `fminmax_skel`: `maxnum` of the `half` values 0, 1 and 1, 1 on two
scopes gives related results; the twins of its premises that the flags have no `nnan` and no
`ninf`: with `nnan` a NaN operand, and with `ninf` an infinite one, gives `poison`, and 0 a word
(`maxnum_skel`). The instance of `rsqrt_skel`: `rsqrt.approx` of 1 and of 4 under two oracle
numbers gives related results, the words of 1 and 0.5; the twins of its premises on the flags:
with `nnan` it gives `poison` at -1, and with `ninf` at `+0`, and a word at 1 (`approx_skel`).

The instances of `withAttrs_skel`: `noundef` on the related words 1 and 2 on `memX 1` and
`memX 2` gives related results, 1 the first, and `nonnull` on a pointer to block 1 on both gives
related results; the twin of its premise that no attribute is a `range` or the values are equal:
`range i8 0, 2` gives 1 on the word 1 and `poison` on the word 2, which are not related
(`attrs_skel`).

The twin of the skeleton relation's premise (T3b) that the two runs have one address choice:
from `start2`'s grid (MojoProofTest/Confluence.lean), whose memory is related to
itself, thread 0's `alloca i32` under `c2` and under `c2'`, which differs from `c2` only in the
address choices, makes block 2 at address 0 and at address 4, so the memories after are related
for no set of payload blocks (`addr_twin`).

Statements about these values, memories and grids.
-/

namespace MojoProofTest.Skeleton

open MojoProof.Sem MojoProofTest.Confluence MojoProofTest.Determinism

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The instance of `Val.Skel`: two aggregates whose data words differ, inside a vector with a
pointer lane and outside, are related; the twins: two pointers to different blocks, words of two
widths, and a word and `poison` are not. -/
theorem skel_vals : Val.Skel (.agg [.vec [.bits 8 1, .ptr ⟨1, 0⟩], .bits 32 5])
      (.agg [.vec [.bits 8 2, .ptr ⟨1, 0⟩], .bits 32 6]) ∧
    ¬ Val.Skel (.ptr ⟨1, 0⟩) (.ptr ⟨2, 0⟩) ∧ ¬ Val.Skel (.bits 8 1) (.bits 16 1) ∧
    ¬ Val.Skel (.bits 8 1) .poison := by
  refine ⟨rfl, ?_, ?_, ?_⟩ <;> intro h <;> simp [Val.Skel, Val.erase] at h

/-- `Close.blk` with 4 bytes, byte 0 the data byte `x` and the others undefined. -/
def blkX (x : BitVec 8) : Block :=
  { MojoProofTest.Close.blk with size := 4, bytes := fun i => if i = 0 then .byte x else .undef }

/-- Block 1 is `blkX x`, and `next = 2`. -/
def memX (x : BitVec 8) : Mem :=
  { blocks := fun c => if c = 1 then some (blkX x) else none, next := 2 }

/-- The instance of `Mem.SkelEq`: `memX 1` and `memX 2` are related when block 1 is payload, and
not when no block is. -/
theorem skel_pay :
    (memX 1).SkelEq (· = 1) (memX 2) ∧ ¬ (memX 1).SkelEq (fun _ => False) (memX 2) := by
  refine ⟨⟨rfl, rfl, fun b => ?_⟩, fun h => ?_⟩
  · by_cases hb : b = 1
    · subst hb
      show Option.Rel _ (some (blkX 1)) (some (blkX 2))
      refine .some ⟨rfl, fun i => ?_, fun h => (h rfl).elim⟩
      by_cases hi : i = 0
      · subst hi
        rfl
      · exact congrArg MemByte.erase (by simp [blkX, hi])
    · have e : ∀ x, (memX x).blocks b = none := fun _ => ite_eq_right hb
      rw [e, e]
      exact .none
  · have hb := h.blocks 1
    change Option.Rel _ (some (blkX 1)) (some (blkX 2)) at hb
    cases hb with
    | some hB => exact absurd (hB.same id 0) (by decide)

/-- One frame of the default function, at its start, whose register 0 holds the data word `x`. -/
def thrX (x : BitVec 8) : Thread where
  frames := [{
    fn := default, label := 0, pc := 0,
    regs := fun r => if r = 0 then some (.bits 8 x) else none, prods := fun _ => none,
    allocas := [], dest := none }]
  k := 0

/-- Register 0 of every function is payload when `p`, and no other register is. -/
def lab0 (p : Bool) : Labels := { reg := fun _ r => p && r == 0, ret := fun _ => false }

/-- The instance of `Thread.Skel`: `thrX 1` and `thrX 2` are related when register 0 is payload,
and not when no register is. -/
theorem skel_thread :
    (thrX 1).Skel (lab0 true) (thrX 2) ∧ ¬ (thrX 1).Skel (lab0 false) (thrX 2) := by
  refine ⟨⟨rfl, .cons ⟨rfl, fun r => ?_, fun _ => .none⟩ .nil⟩, fun h => ?_⟩
  · by_cases hr : r = 0
    · subst hr
      exact .some (show Val.Skel (.bits 8 1) (.bits 8 2) from rfl)
    · have e : ∀ x : BitVec 8, (if r = 0 then some (Val.bits 8 x) else none) = none :=
        fun _ => ite_eq_right hr
      show Option.Rel _ (if r = 0 then _ else none) (if r = 0 then _ else none)
      rw [e, e]
      exact .none
  · obtain ⟨_, hf⟩ := h
    cases hf with
    | cons hF _ =>
      have h0 := hF.regs 0
      change Option.Rel _ (some (Val.bits 8 1)) (some (Val.bits 8 2)) at h0
      cases h0 with
      | some h =>
        change Val.bits 8 1 = .bits 8 2 at h
        cases h

/-- One running thread `thrX x` on `memX x`. -/
def gridX (x : BitVec 8) : Grid := { threads := #[.run (thrX x)], mem := memX x }

/-- `regT` (MojoProofTest/Confluence.lean), at a statement whose result is register 0, waiting at
a butterfly shuffle (`shflFn`) of the full mask whose exchanged value is `x` and lane operand `b`. -/
def shflX (x b : BitVec 32) : Status :=
  .wait regT (.shfl .bfly) [.bits 32 (-1), .bits 32 x, .bits 32 b, .bits 32 31] shflFn

/-- The instance of `Grid.SkelRel`: `gridX 1` and `gridX 2` are related when register 0 and
block 1 are payload. The instance of `Status.Skel` at a shuffle: two threads waiting at it whose
exchanged values differ are related when its result, register 0, is payload; the twins: they are
not when it is not (`Thread.payRes`), nor when their lane operands differ
(`Intrinsic.eraseArgs`). -/
theorem skel_grid : (gridX 1).SkelRel (lab0 true) (· = 1) (gridX 2) ∧
    (shflX 5 0).Skel (lab0 true) (shflX 6 0) ∧ ¬ (shflX 5 0).Skel (lab0 false) (shflX 6 0) ∧
    ¬ (shflX 5 0).Skel (lab0 true) (shflX 5 1) := by
  refine ⟨⟨fun n => ?_, skel_pay.1⟩, ⟨.refl _ _, rfl, rfl, rfl⟩, fun h => ?_, fun h => ?_⟩
  · match n with
    | 0 => exact .some skel_thread.1
    | n + 1 =>
      rw [show (gridX 1).threads[n + 1]? = none by simp [gridX],
        show (gridX 2).threads[n + 1]? = none by simp [gridX]]
      exact .none
  · have e : [Val.bits 32 (-1), .bits 32 5, .bits 32 0, .bits 32 31] =
        [.bits 32 (-1), .bits 32 6, .bits 32 0, .bits 32 31] := h.2.2.2
    simp at e
  · have e := h.2.2.2
    simp [Labels.Rel, Thread.payRes, MojoProof.LLVM.Intrinsic.eraseArgs, Val.erase] at e

/-- `c2` with address choice 1 everywhere. -/
def c2' (n : Nat) : Ctx := { c2 n with addr := fun _ => 1 }

/-- Counterexample (iii), the twin of T3b's premise of one address choice: `start2`'s memory is
related to itself, thread 0's `alloca` steps under `c2` and under `c2'`, and the memories after
are related for no set of payload blocks (related blocks have one address). -/
theorem addr_twin (pay : Nat → Prop) : run2.1.mem.SkelEq pay run2.1.mem ∧
    Grid.Step two c2 run2.1 (adv c2 run2.1 0) ∧ Grid.Step two c2' run2.1 (adv c2' run2.1 0) ∧
    ¬ (adv c2 run2.1 0).mem.SkelEq pay (adv c2' run2.1 0).mem := by
  refine ⟨.refl pay _, ⟨0, .inl rfl⟩, ⟨0, .inl rfl⟩, fun h => ?_⟩
  have e := (h.blocks 2).map_eq (f := Block.addr) fun hB => (congrArg Block.addr hB.shape :)
  rw [show ((adv c2 run2.1 0).mem.blocks 2).map Block.addr = some 0 from rfl,
    show ((adv c2' run2.1 0).mem.blocks 2).map Block.addr = some 4 from rfl] at e
  cases e

/-- The twins of `Layout.decode_erase`'s premises: the `i1` that the byte 2 holds is poison, and
the one its erasure holds is a word (the premise `Ty.data`); the `i8` that the bytes 1 and 1 hold
is poison, and the one their erasure holds is a word (the premise of at most `l.stored t` bytes). -/
theorem decode_twins :
    (Layout.decode {} (.int 1) [.byte 2]).map Val.erase ≠
      (Layout.decode {} (.int 1) ([.byte 2].map MemByte.erase)).map Val.erase ∧
    (Layout.decode {} (.int 8) [.byte 1, .byte 1]).map Val.erase ≠
      (Layout.decode {} (.int 8) ([.byte 1, .byte 1].map MemByte.erase)).map Val.erase := by
  simp only [Layout.decode]
  change some Val.poison ≠ some (.bits 1 0) ∧ some Val.poison ≠ some (.bits 8 0)
  exact ⟨nofun, nofun⟩

/-- The instance of `Mem.load_skel`: with block 1 payload (`skel_pay`), the `i8` loads from block
1 of `memX 1` and `memX 2` give the data words 1 and 2, which are related. The twin of its premise
that a payload block is loaded at a data type: the `i1` loads give the `i1` 1 and poison (the
byte 2 is no `i1`), which are not. -/
theorem load_skel :
    (memX 1).load {} ⟨0, 0⟩ 0 (.int 8) ⟨1, 0⟩ none = .ok (.bits 8 1) ∧
    (memX 2).load {} ⟨0, 0⟩ 0 (.int 8) ⟨1, 0⟩ none = .ok (.bits 8 2) ∧
    Except.Rel (fun v₁ v₂ => v₁.Skel v₂ ∧ (¬ 1 = 1 → v₁ = v₂))
      ((memX 1).load {} ⟨0, 0⟩ 0 (.int 8) ⟨1, 0⟩ none)
      ((memX 2).load {} ⟨0, 0⟩ 0 (.int 8) ⟨1, 0⟩ none) ∧
    (memX 1).load {} ⟨0, 0⟩ 0 (.int 1) ⟨1, 0⟩ none = .ok (.bits 1 1) ∧
    (memX 2).load {} ⟨0, 0⟩ 0 (.int 1) ⟨1, 0⟩ none = .ok .poison ∧
    ¬ Val.Skel (.bits 1 1) .poison := by
  refine ⟨?_, ?_, Mem.load_skel (t := .int 8) (p := ⟨1, 0⟩) skel_pay.1
    (fun _ => by simp [MojoProof.LLVM.Ty.data]) {} ⟨0, 0⟩ 0 none, ?_, ?_, ?_⟩
  · simp only [Mem.load, Layout.decode]; rfl
  · simp only [Mem.load, Layout.decode]; rfl
  · simp only [Mem.load, Layout.decode]; rfl
  · simp only [Mem.load, Layout.decode]; rfl
  · intro h
    simp [Val.Skel, Val.erase] at h

/-- The instance of `Mem.store_skel`: with block 1 payload (`skel_pay`), the `i8` stores of the
data words 5 and 6 to block 1 of `memX 1` and `memX 2` give related memories. The twin of its
premise that the values are equal if the block is not payload: with no block payload, the same
stores to `memX 1` give memories that are not related. -/
theorem store_skel :
    Except.Rel (Mem.SkelEq (· = 1))
      ((memX 1).store {} ⟨0, 0⟩ 0 (.int 8) (.bits 8 5) ⟨1, 0⟩ none)
      ((memX 2).store {} ⟨0, 0⟩ 0 (.int 8) (.bits 8 6) ⟨1, 0⟩ none) ∧
    ¬ Except.Rel (Mem.SkelEq fun _ => False)
      ((memX 1).store {} ⟨0, 0⟩ 0 (.int 8) (.bits 8 5) ⟨1, 0⟩ none)
      ((memX 1).store {} ⟨0, 0⟩ 0 (.int 8) (.bits 8 6) ⟨1, 0⟩ none) := by
  refine ⟨Mem.store_skel (v₁ := .bits 8 5) (v₂ := .bits 8 6) (p := ⟨1, 0⟩) skel_pay.1 rfl
    (fun h => (h rfl).elim) {} ⟨0, 0⟩ 0 (.int 8) none none, fun h => ?_⟩
  obtain ⟨m₅, e₅, b₅⟩ : ∃ m, (memX 1).store {} ⟨0, 0⟩ 0 (.int 8) (.bits 8 5) ⟨1, 0⟩ none = .ok m ∧
      m.blocks 1 = some ((blkX 1).put 0 [.byte 5]) :=
    ⟨_, by simp only [Mem.store, Layout.encode]; rfl, rfl⟩
  obtain ⟨m₆, e₆, b₆⟩ : ∃ m, (memX 1).store {} ⟨0, 0⟩ 0 (.int 8) (.bits 8 6) ⟨1, 0⟩ none = .ok m ∧
      m.blocks 1 = some ((blkX 1).put 0 [.byte 6]) :=
    ⟨_, by simp only [Mem.store, Layout.encode]; rfl, rfl⟩
  rw [e₅, e₆] at h
  cases h with
  | ok h =>
    have hb := h.blocks 1
    rw [b₅, b₆] at hb
    cases hb with
    | some hB => exact absurd (hB.same id 0) (by decide)

/-- The instances of `Mem.alloc_skel` and `Mem.setLive_skel`: with block 1 payload (`skel_pay`),
for every layout and block fields, an allocation in `memX 1` and `memX 2` gives related memories
and block 2 in both, and setting block 1 dead gives related memories. -/
theorem alloc_skel (l : Layout) (space size align : Nat) (live readOnly : Bool) (owner : Owner)
    (addr gaddr : Nat) :
    ((memX 1).alloc l space size align live readOnly owner addr gaddr).1.SkelEq (· = 1)
      ((memX 2).alloc l space size align live readOnly owner addr gaddr).1 ∧
    ((memX 1).alloc l space size align live readOnly owner addr gaddr).2 = 2 ∧
    ((memX 1).setLive 1 false).SkelEq (· = 1) ((memX 2).setLive 1 false) :=
  ⟨(Mem.alloc_skel skel_pay.1 l space size align live readOnly owner addr gaddr [] none).1, rfl,
    Mem.setLive_skel skel_pay.1 1 false⟩

/-- A scope on `memX x` whose register 0 holds a pointer to block 1 and the others the data word
`x`. -/
def sX (x : BitVec 8) : Scope :=
  { layout := {}, mem := memX x, globals := fun _ => none,
    regs := fun n => if n = 0 then some (.ptr ⟨1, 0⟩) else some (.bits 8 x), ch := fun _ => 0 }

/-- The instance of `evalV_skel`: with block 1 payload (`skel_pay`), the `ptrtoint` of register 0
gives one result on `sX 1` and on `sX 1` with the memory and registers of `sX 2`, which are equal
at register 0 (outside `p`, every register but 0), and other oracle numbers. The twin of its
premise that the registers outside `p` are equal: register 1 gives the data words 2 and 1. -/
theorem eval_skel :
    evalV { sX 1 with mem := memX 2, regs := (sX 2).regs, ch := fun _ => 1 } (.int 64)
      (.cast .ptrtoint ⟨.ptr 0, .loc 0⟩ (.int 64)) =
      evalV (sX 1) (.int 64) (.cast .ptrtoint ⟨.ptr 0, .loc 0⟩ (.int 64)) ∧
    evalV { sX 1 with mem := memX 2, regs := (sX 2).regs } (.int 8) (.loc 1) = .ok (.bits 8 2) ∧
    evalV (sX 1) (.int 8) (.loc 1) = .ok (.bits 8 1) ∧
    (.ok (.bits 8 2) : Except Fault Val) ≠ .ok (.bits 8 1) := by
  refine ⟨(evalV_skel (p := (· != 0)) skel_pay.1 fun n hn => ?_).1 _ _ rfl, rfl, rfl, by simp⟩
  simp only [bne_eq_false_iff_eq] at hn
  subst hn
  rfl

/-- The `fpext` of the `half` NaN `0xH7E00`. -/
def nanExt : MojoProof.LLVM.Value := .cast .fpext ⟨.fp .half, .float (.hex "H" 0x7E00)⟩ (.fp .float)

/-- Why `evalV_skel` needs `CastOp.const`: as an instruction, `fpext` of the
`half` NaN gives the NaN words `0x7fc00000` and `0x7fc00001` under two oracle numbers, which are
related but not equal. As an operand (a constant expression, which LangRef does not allow for
`fpext`), it is refused on every scope. -/
theorem fpext_twin (s : Scope) :
    castV {} s.mem .fpext (.fp .half) (.bits 16 0x7E00) (.fp .float) (fun _ => 0x7fc00000) =
      .ok (.bits 32 0x7fc00000) ∧
    castV {} s.mem .fpext (.fp .half) (.bits 16 0x7E00) (.fp .float) (fun _ => 0x7fc00001) =
      .ok (.bits 32 0x7fc00001) ∧
    Val.Skel (.bits 32 0x7fc00000) (.bits 32 0x7fc00001) ∧
    evalV s (.fp .float) nanExt =
      .error (.unsupported "constant expression cast LangRef does not allow") :=
  ⟨rfl, rfl, rfl, rfl⟩

/-- A lane function that reads the word: `poison` for the word 1 (as `or disjoint` and `fadd nnan`
make `poison` of some operands), the word 0 for the other words. -/
def oneP : Nat → Val → Except Fault Val
  | _, .bits _ b => pure (if b.toNat = 1 then .poison else .bits 8 0)
  | _, v => pure v

/-- The instance of `lanes_skel` with `intCast_skel`: `trunc` to `i4` of the related vectors
`<1, poison>` and `<2, poison>` gives related results, `<1, poison>` the first. The twin of its
premise that the lane function gives related results on related lanes: `oneP` on `<1>` and `<2>`
gives `<poison>` and `<0>`, which are not related. -/
theorem trunc_skel :
    Except.Rel Val.Skel (lanes (fun _ => intCast .trunc 4) (.vec [.bits 8 1, .poison]))
      (lanes (fun _ => intCast .trunc 4) (.vec [.bits 8 2, .poison])) ∧
    lanes (fun _ => intCast .trunc 4) (.vec [.bits 8 1, .poison]) = .ok (.vec [.bits 4 1, .poison]) ∧
    ¬ Except.Rel Val.Skel (lanes oneP (.vec [.bits 8 1])) (lanes oneP (.vec [.bits 8 2])) := by
  refine ⟨lanes_skel (fun _ _ _ h => intCast_skel .trunc 4 h) rfl, rfl, fun h => ?_⟩
  have e₁ : lanes oneP (.vec [.bits 8 1]) = .ok (.vec [.poison]) := rfl
  have e₂ : lanes oneP (.vec [.bits 8 2]) = .ok (.vec [.bits 8 0]) := rfl
  rw [e₁, e₂] at h
  cases h with
  | ok h => simp [Val.Skel, Val.erase, Val.eraseAll_eq] at h

/-- The instance of `lanes2_skel`: the lane function that pairs its lanes in an aggregate, on the
related vectors `<1>`, `<3>` and `<2>`, `<4>`, gives related results. The twin of its premise that
the lane function gives related results on related lanes: `oneP` of the first lane, on `<1>`,
`<0>` and `<2>`, `<0>`, gives `<poison>` and `<0>`, which are not related. -/
theorem pair_skel :
    Except.Rel Val.Skel (lanes2 (fun _ x y => pure (.agg [x, y])) (.vec [.bits 8 1]) (.vec [.bits 8 3]))
      (lanes2 (fun _ x y => pure (.agg [x, y])) (.vec [.bits 8 2]) (.vec [.bits 8 4])) ∧
    ¬ Except.Rel Val.Skel (lanes2 (fun _ x _ => oneP 0 x) (.vec [.bits 8 1]) (.vec [.bits 8 0]))
      (lanes2 (fun _ x _ => oneP 0 x) (.vec [.bits 8 2]) (.vec [.bits 8 0])) := by
  refine ⟨lanes2_skel (P := False) ?_ rfl rfl False.elim, fun h => ?_⟩
  · rintro _ x₁ x₂ y₁ y₂ (h₁ : x₁.erase = x₂.erase) (h₂ : y₁.erase = y₂.erase) -
    exact .ok (show Val.agg (Val.eraseAll [x₁, y₁]) = Val.agg (Val.eraseAll [x₂, y₂]) by
      simp only [Val.eraseAll_eq, List.map_cons, List.map_nil, h₁, h₂])
  have e₁ : lanes2 (fun _ x _ => oneP 0 x) (.vec [.bits 8 1]) (.vec [.bits 8 0]) =
      .ok (.vec [.poison]) := rfl
  have e₂ : lanes2 (fun _ x _ => oneP 0 x) (.vec [.bits 8 2]) (.vec [.bits 8 0]) =
      .ok (.vec [.bits 8 0]) := rfl
  rw [e₁, e₂] at h
  cases h with
  | ok h => simp [Val.Skel, Val.erase, Val.eraseAll_eq] at h

/-- The instance of `intBin_skel` with `lanes2_skel`: `add` of the related vectors `<1, poison>`,
`<3, 4>` and `<2, poison>`, `<5, 4>` gives related results, `<4, poison>` the first; `shl` of the
related vectors `<1>` and `<2>` by `<9>` (an amount of at least the width) gives related results.
The twins of the premise `BinOp.total`: `or disjoint` of 1 and 2 gives 3, and of 1 and 1 `poison`,
which are not related; `sdiv` of -128 by -1 faults, and of 0 by -1 gives 0 (a fault and a value
are not related). The twin of the premise that a shift amount is skeleton (`BinOp.skelB`): `shl`
of `<1>` by `<1>` gives `<2>`, and by `<9>` `<poison>`, which are not related. -/
theorem bin_skel :
    Except.Rel Val.Skel
      (lanes2 (fun _ => intBin 8 .add {}) (.vec [.bits 8 1, .poison]) (.vec [.bits 8 3, .bits 8 4]))
      (lanes2 (fun _ => intBin 8 .add {}) (.vec [.bits 8 2, .poison])
        (.vec [.bits 8 5, .bits 8 4])) ∧
    lanes2 (fun _ => intBin 8 .add {}) (.vec [.bits 8 1, .poison]) (.vec [.bits 8 3, .bits 8 4]) =
      .ok (.vec [.bits 8 4, .poison]) ∧
    Except.Rel Val.Skel (lanes2 (fun _ => intBin 8 .shl {}) (.vec [.bits 8 1]) (.vec [.bits 8 9]))
      (lanes2 (fun _ => intBin 8 .shl {}) (.vec [.bits 8 2]) (.vec [.bits 8 9])) ∧
    intBin 8 .or { disjoint := true } (.bits 8 1) (.bits 8 2) = .ok (.bits 8 3) ∧
    intBin 8 .or { disjoint := true } (.bits 8 1) (.bits 8 1) = .ok .poison ∧
    ¬ Val.Skel (.bits 8 3) .poison ∧
    intBin 8 .sdiv {} (.bits 8 (-128)) (.bits 8 (-1)) = .error (.ub "sdiv overflow") ∧
    intBin 8 .sdiv {} (.bits 8 0) (.bits 8 (-1)) = .ok (.bits 8 0) ∧
    lanes2 (fun _ => intBin 8 .shl {}) (.vec [.bits 8 1]) (.vec [.bits 8 1]) =
      .ok (.vec [.bits 8 2]) ∧
    lanes2 (fun _ => intBin 8 .shl {}) (.vec [.bits 8 1]) (.vec [.bits 8 9]) =
      .ok (.vec [.poison]) ∧
    ¬ Val.Skel (.vec [.bits 8 2]) (.vec [.poison]) := by
  refine ⟨lanes2_skel (P := MojoProof.LLVM.BinOp.add.skelB = true)
      (fun _ _ _ _ _ hx hy hb => intBin_skel 8 rfl hx hy hb) rfl rfl nofun, rfl,
    lanes2_skel (P := MojoProof.LLVM.BinOp.shl.skelB = true)
      (fun _ _ _ _ _ hx hy hb => intBin_skel 8 rfl hx hy hb) rfl rfl fun _ => rfl,
    rfl, rfl, ?_, rfl, rfl, rfl, rfl, ?_⟩ <;> intro h <;>
    simp [Val.Skel, Val.erase, Val.eraseAll_eq] at h

/-- The instance of `icmpV_skel`: with block 1 payload (`skel_pay`), `icmp ult` of 1 by 2 on
`memX 1` and of 3 by 2 on `memX 2` gives related results, `true` and `false`; `icmp eq` of the
pointer to block 1 with itself on `memX 1` and on `memX 2` gives related results. The twin of its
premise that the memories are related: on a memory with no block 1 the pointer comparison faults,
and on `memX 1` it gives `true` (a fault and a value are not related). The twin of its premise
that the values are related: `icmp eq` of the `i8` 1 with the `i8` 1 gives `true`, and with the
`i16` 1 faults. -/
theorem icmp_skel :
    Except.Rel Val.Skel (icmpV {} (memX 1) .ult (.int 8) (.bits 8 1) (.bits 8 2))
      (icmpV {} (memX 2) .ult (.int 8) (.bits 8 3) (.bits 8 2)) ∧
    icmpV {} (memX 1) .ult (.int 8) (.bits 8 1) (.bits 8 2) = .ok (.bits 1 1) ∧
    icmpV {} (memX 2) .ult (.int 8) (.bits 8 3) (.bits 8 2) = .ok (.bits 1 0) ∧
    Except.Rel Val.Skel (icmpV {} (memX 1) .eq (.ptr 0) (.ptr ⟨1, 0⟩) (.ptr ⟨1, 0⟩))
      (icmpV {} (memX 2) .eq (.ptr 0) (.ptr ⟨1, 0⟩) (.ptr ⟨1, 0⟩)) ∧
    icmpV {} (memX 1) .eq (.ptr 0) (.ptr ⟨1, 0⟩) (.ptr ⟨1, 0⟩) = .ok (.bits 1 1) ∧
    icmpV {} { memX 1 with blocks := fun _ => none } .eq (.ptr 0) (.ptr ⟨1, 0⟩) (.ptr ⟨1, 0⟩) =
      .error (.ub "pointer to no block") ∧
    icmpV {} (memX 1) .eq (.int 8) (.bits 8 1) (.bits 8 1) = .ok (.bits 1 1) ∧
    icmpV {} (memX 1) .eq (.int 8) (.bits 8 1) (.bits 16 1) =
      .error (.unsupported "icmp operands of different widths") :=
  ⟨icmpV_skel skel_pay.1 _ _ _ rfl rfl, rfl, rfl, icmpV_skel skel_pay.1 _ _ _ rfl rfl, rfl, rfl,
    rfl, rfl⟩

/-- The instance of `floatBin_skel`: `fadd` of the `half` NaN `0xH7E00` and 0 under the oracle
numbers 0 and `3 * 0x7E01` gives related results, the NaN word `0x7E01` the second. The twins of
its premises that the flags have no `nnan` and no `ninf`: `fadd nnan` of 0 and 0 gives 0, and of
the NaN and 0 `poison`; `fadd ninf` of 0 and 0 gives 0, and of the infinity `0xH7C00` and 0
`poison`; not related. Likewise for `fcmpV_skel`: `fcmp oeq` of 0 and 0 and of 1 (`0xH3C00`)
and 0 gives related results; the twins: `fcmp oeq` of 0 and 0 gives `true` and, with `nnan` of
the NaN and 0 and with `ninf` of the infinity and 0, `poison`. And for `fnegV_skel`: `fneg` of 0
and of 1 gives related results; the twins: `fneg` of 0 gives `-0` (`0xH8000`) and, with `nnan` of
the NaN and with `ninf` of the infinity, `poison`. -/
theorem float_skel :
    Except.Rel Val.Skel (floatBin .half .fadd {} (.bits 16 0x7E00) (.bits 16 0) none none 0)
      (floatBin .half .fadd {} (.bits 16 0x7E00) (.bits 16 0) none none (3 * 0x7E01)) ∧
    floatBin .half .fadd {} (.bits 16 0x7E00) (.bits 16 0) none none (3 * 0x7E01) =
      .ok (.bits 16 0x7E01) ∧
    floatBin .half .fadd { nnan := true } (.bits 16 0) (.bits 16 0) none none 0 =
      .ok (.bits 16 0) ∧
    floatBin .half .fadd { nnan := true } (.bits 16 0x7E00) (.bits 16 0) none none 0 =
      .ok .poison ∧
    floatBin .half .fadd { ninf := true } (.bits 16 0) (.bits 16 0) none none 0 =
      .ok (.bits 16 0) ∧
    floatBin .half .fadd { ninf := true } (.bits 16 0x7C00) (.bits 16 0) none none 0 =
      .ok .poison ∧
    ¬ Val.Skel (.bits 16 0) .poison ∧
    Except.Rel Val.Skel (fcmpV {} .oeq (.fp .half) (.bits 16 0) (.bits 16 0))
      (fcmpV {} .oeq (.fp .half) (.bits 16 0x3C00) (.bits 16 0)) ∧
    fcmpV { nnan := true, ninf := true } .oeq (.fp .half) (.bits 16 0) (.bits 16 0) =
      .ok (.bits 1 1) ∧
    fcmpV { nnan := true } .oeq (.fp .half) (.bits 16 0x7E00) (.bits 16 0) = .ok .poison ∧
    fcmpV { ninf := true } .oeq (.fp .half) (.bits 16 0x7C00) (.bits 16 0) = .ok .poison ∧
    ¬ Val.Skel (.bits 1 1) .poison ∧
    Except.Rel Val.Skel (fnegV {} (.fp .half) (.bits 16 0))
      (fnegV {} (.fp .half) (.bits 16 0x3C00)) ∧
    fnegV { nnan := true, ninf := true } (.fp .half) (.bits 16 0) = .ok (.bits 16 0x8000) ∧
    fnegV { nnan := true } (.fp .half) (.bits 16 0x7E00) = .ok .poison ∧
    fnegV { ninf := true } (.fp .half) (.bits 16 0x7C00) = .ok .poison ∧
    ¬ Val.Skel (.bits 16 0x8000) .poison := by
  refine ⟨floatBin_skel .half .fadd rfl rfl rfl rfl _ _ _ _ _ _, rfl, rfl, rfl, rfl, rfl, ?_,
    fcmpV_skel rfl rfl _ _ rfl rfl, rfl, rfl, rfl, ?_, fnegV_skel rfl rfl _ rfl, rfl, rfl, rfl,
    ?_⟩ <;> intro h <;> simp [Val.Skel, Val.erase] at h

/-- The pointer to block 1. -/
abbrev p1 : Val := .ptr ⟨1, 0⟩

/-- The instance of `selectV_skel`: `select` on `<true, false>` of the related vectors `<1, 2>`,
`<3, 4>` and `<5, 2>`, `<3, 6>` gives related results, `<1, 4>` the first. The twin of its premise
that the two conditions are one: `select` of the pointers to blocks 1 and 2 on `true` gives the
first, and on `false` the second, which are not related. -/
theorem select_skel :
    Except.Rel Val.Skel
      (selectV (.vec 2 (.int 8)) (.vec [.bits 1 1, .bits 1 0]) (.vec [.bits 8 1, .bits 8 2])
        (.vec [.bits 8 3, .bits 8 4]))
      (selectV (.vec 2 (.int 8)) (.vec [.bits 1 1, .bits 1 0]) (.vec [.bits 8 5, .bits 8 2])
        (.vec [.bits 8 3, .bits 8 6])) ∧
    selectV (.vec 2 (.int 8)) (.vec [.bits 1 1, .bits 1 0]) (.vec [.bits 8 1, .bits 8 2])
      (.vec [.bits 8 3, .bits 8 4]) = .ok (.vec [.bits 8 1, .bits 8 4]) ∧
    selectV (.ptr 0) (.bits 1 1) p1 (.ptr ⟨2, 0⟩) = .ok p1 ∧
    selectV (.ptr 0) (.bits 1 0) p1 (.ptr ⟨2, 0⟩) = .ok (.ptr ⟨2, 0⟩) ∧
    ¬ Val.Skel p1 (.ptr ⟨2, 0⟩) := by
  refine ⟨selectV_skel _ _ ?_ ?_, rfl, rfl, rfl, ?_⟩
  iterate 2 exact rfl
  intro h
  simp [Val.Skel, Val.erase] at h

/-- The instances of `extractE_skel` and `insertE_skel`: `extractelement` at 0 of the related
`<2 x i8>` vectors `<1, poison>` and `<2, poison>` gives related results, 1 the first, and
`insertelement` at 0 of 1 and of 2 into `<poison, poison>` gives related results,
`<1, poison>` the first. The twins of their premises that the two indices are one:
`extractelement` of `<1, poison>` at 0 and at 1 gives 1 and `poison`, and `insertelement` of 1 into
`<poison, poison>` at 0 and at 1 gives `<1, poison>` and `<poison, 1>`, which are not related. -/
theorem elem_skel :
    Except.Rel Val.Skel (extractE (.vec 2 (.int 8)) (.vec [.bits 8 1, .poison]) (.bits 32 0))
      (extractE (.vec 2 (.int 8)) (.vec [.bits 8 2, .poison]) (.bits 32 0)) ∧
    extractE (.vec 2 (.int 8)) (.vec [.bits 8 1, .poison]) (.bits 32 0) = .ok (.bits 8 1) ∧
    Except.Rel Val.Skel
      (insertE (.vec 2 (.int 8)) (.vec [.poison, .poison]) (.bits 8 1) (.bits 32 0))
      (insertE (.vec 2 (.int 8)) (.vec [.poison, .poison]) (.bits 8 2) (.bits 32 0)) ∧
    insertE (.vec 2 (.int 8)) (.vec [.poison, .poison]) (.bits 8 1) (.bits 32 0) =
      .ok (.vec [.bits 8 1, .poison]) ∧
    extractE (.vec 2 (.int 8)) (.vec [.bits 8 1, .poison]) (.bits 32 1) = .ok .poison ∧
    ¬ Val.Skel (.bits 8 1) .poison ∧
    insertE (.vec 2 (.int 8)) (.vec [.poison, .poison]) (.bits 8 1) (.bits 32 1) =
      .ok (.vec [.poison, .bits 8 1]) ∧
    ¬ Val.Skel (.vec [.bits 8 1, .poison]) (.vec [.poison, .bits 8 1]) := by
  refine ⟨extractE_skel _ ?_ _, rfl, insertE_skel _ rfl ?_ _, rfl, rfl, ?_, rfl, ?_⟩
  iterate 2 exact rfl
  all_goals intro h; simp [Val.Skel, Val.erase, Val.eraseAll_eq] at h

/-- The instance of `shuffleV_skel`: `shufflevector` by the mask `<1, 0>` of the related
`<1 x i8>` vectors `<1>`, `<poison>` and `<2>`, `<poison>` gives related results, `<poison, 1>`
the first. The twin of its premise that the two masks are one: `shufflevector` of `<1>` and
`<poison>` by `<0>` and by `<1>` gives `<1>` and `<poison>`, which are not related. -/
theorem shuffle_skel :
    Except.Rel Val.Skel
      (shuffleV (.vec 1 (.int 8)) (.vec [.bits 8 1]) (.vec [.poison])
        (.vec [.bits 32 1, .bits 32 0]))
      (shuffleV (.vec 1 (.int 8)) (.vec [.bits 8 2]) (.vec [.poison])
        (.vec [.bits 32 1, .bits 32 0])) ∧
    shuffleV (.vec 1 (.int 8)) (.vec [.bits 8 1]) (.vec [.poison])
      (.vec [.bits 32 1, .bits 32 0]) = .ok (.vec [.poison, .bits 8 1]) ∧
    shuffleV (.vec 1 (.int 8)) (.vec [.bits 8 1]) (.vec [.poison]) (.vec [.bits 32 0]) =
      .ok (.vec [.bits 8 1]) ∧
    shuffleV (.vec 1 (.int 8)) (.vec [.bits 8 1]) (.vec [.poison]) (.vec [.bits 32 1]) =
      .ok (.vec [.poison]) ∧
    ¬ Val.Skel (.vec [.bits 8 1]) (.vec [.poison]) := by
  refine ⟨shuffleV_skel _ ?_ rfl _, rfl, rfl, rfl, ?_⟩
  · exact rfl
  intro h
  simp [Val.Skel, Val.erase, Val.eraseAll_eq] at h

/-- The instances of `extractV_skel` and `insertV_skel`, with `p1` the pointer to block 1:
`extractvalue` at `[0]` of the related `{i8, ptr}` aggregates `{1, p1}` and `{2, p1}` gives related
results, 1 the first, and `insertvalue` at `[0]` of 1 and of 2 into `{poison, p1}` gives related
results, `{1, p1}` the first. The twins of their premises that the two index lists are one:
`extractvalue` of `{1, p1}` at `[0]` and at `[1]` gives 1 and `p1`, and `insertvalue` of 1 into the
`{i8, i8}` aggregate `{poison, poison}` at `[0]` and at `[1]` gives `{1, poison}` and
`{poison, 1}`, which are not related. -/
theorem value_skel :
    Except.Rel Val.Skel (extractV (.agg [.bits 8 1, p1]) [0])
      (extractV (.agg [.bits 8 2, p1]) [0]) ∧
    extractV (.agg [.bits 8 1, p1]) [0] = .ok (.bits 8 1) ∧
    Except.Rel Val.Skel (insertV (.agg [.poison, p1]) (.bits 8 1) [0])
      (insertV (.agg [.poison, p1]) (.bits 8 2) [0]) ∧
    insertV (.agg [.poison, p1]) (.bits 8 1) [0] = .ok (.agg [.bits 8 1, p1]) ∧
    extractV (.agg [.bits 8 1, p1]) [1] = .ok p1 ∧
    ¬ Val.Skel (.bits 8 1) p1 ∧
    insertV (.agg [.poison, .poison]) (.bits 8 1) [0] = .ok (.agg [.bits 8 1, .poison]) ∧
    insertV (.agg [.poison, .poison]) (.bits 8 1) [1] = .ok (.agg [.poison, .bits 8 1]) ∧
    ¬ Val.Skel (.agg [.bits 8 1, .poison]) (.agg [.poison, .bits 8 1]) := by
  refine ⟨extractV_skel _ ?_, rfl, insertV_skel ?_ _ rfl, rfl, rfl, ?_, rfl, rfl, ?_⟩
  iterate 2 exact rfl
  all_goals intro h; simp [Val.Skel, Val.erase, Val.eraseAll_eq] at h

/-- The instances of `castV_skel`, with block 1 payload (`skel_pay`): `fpext` of the `half` NaN
`0xH7E00` on `memX 1` and `memX 2` under two oracle numbers gives related results; `bitcast` of
the related vectors `<1, 2>` and `<3, 2>` to `i16` gives related results, `0x0201` the first; and
`ptrtoint` of `p1` on `memX 1` and `memX 2` gives related results. The twin of its premise that the
memories are related: on a memory with no block 1 `ptrtoint` of `p1` faults, and on `memX 1` it
gives a word (a fault and a value are not related). -/
theorem cast_skel :
    Except.Rel Val.Skel
      (castV {} (memX 1) .fpext (.fp .half) (.bits 16 0x7E00) (.fp .float) fun _ => 0x7fc00000)
      (castV {} (memX 2) .fpext (.fp .half) (.bits 16 0x7E00) (.fp .float) fun _ => 0x7fc00001) ∧
    Except.Rel Val.Skel
      (castV {} (memX 1) .bitcast (.vec 2 (.int 8)) (.vec [.bits 8 1, .bits 8 2]) (.int 16) id)
      (castV {} (memX 2) .bitcast (.vec 2 (.int 8)) (.vec [.bits 8 3, .bits 8 2]) (.int 16) id) ∧
    castV {} (memX 1) .bitcast (.vec 2 (.int 8)) (.vec [.bits 8 1, .bits 8 2]) (.int 16) id =
      .ok (.bits 16 0x0201) ∧
    Except.Rel Val.Skel (castV {} (memX 1) .ptrtoint (.ptr 0) p1 (.int 64) id)
      (castV {} (memX 2) .ptrtoint (.ptr 0) p1 (.int 64) id) ∧
    castV {} { memX 1 with blocks := fun _ => none } .ptrtoint (.ptr 0) p1 (.int 64) id =
      .error (.ub "pointer to no block") ∧
    (∃ v, castV {} (memX 1) .ptrtoint (.ptr 0) p1 (.int 64) id = .ok v) := by
  refine ⟨castV_skel skel_pay.1 _ _ _ _ rfl _ _, castV_skel skel_pay.1 _ _ _ _ ?_ _ _, rfl,
    castV_skel skel_pay.1 _ _ _ _ rfl _ _, rfl, _, rfl⟩
  exact rfl

/-- The instance of `fminmax_skel`: `maxnum` of the `half` values 0, 1 (`0xH3C00`) and 1, 1 on
two scopes gives related results, 1 the first. The twin of its premises that the flags have no
`nnan` and no `ninf`: `maxnum nnan` of 0 and 1 gives 1, and of the NaN `0xH7E00` and 1 `poison`;
`maxnum ninf` of 0 and 1 gives 1, and of the infinity `0xH7C00` and 1 `poison`. -/
theorem maxnum_skel :
    Except.Rel (Option.Rel fun r₁ r₂ => Option.Rel Val.Skel r₁.1 r₂.1 ∧ r₁.2 = (sX 1).mem ∧
        r₂.2 = (sX 2).mem)
      (intrinsic (c2 0) (sX 1) {} (.fminmax true (.fp .half)) [.bits 16 0, .bits 16 0x3C00])
      (intrinsic (c2 0) (sX 2) {} (.fminmax true (.fp .half))
        [.bits 16 0x3C00, .bits 16 0x3C00]) ∧
    intrinsic (c2 0) (sX 1) {} (.fminmax true (.fp .half)) [.bits 16 0, .bits 16 0x3C00] =
      .ok (some (some (.bits 16 0x3C00), (sX 1).mem)) ∧
    intrinsic (c2 0) (sX 1) { nnan := true } (.fminmax true (.fp .half))
      [.bits 16 0, .bits 16 0x3C00] = .ok (some (some (.bits 16 0x3C00), (sX 1).mem)) ∧
    intrinsic (c2 0) (sX 1) { nnan := true } (.fminmax true (.fp .half))
      [.bits 16 0x7E00, .bits 16 0x3C00] = .ok (some (some .poison, (sX 1).mem)) ∧
    intrinsic (c2 0) (sX 1) { ninf := true } (.fminmax true (.fp .half))
      [.bits 16 0, .bits 16 0x3C00] = .ok (some (some (.bits 16 0x3C00), (sX 1).mem)) ∧
    intrinsic (c2 0) (sX 1) { ninf := true } (.fminmax true (.fp .half))
      [.bits 16 0x7C00, .bits 16 0x3C00] = .ok (some (some .poison, (sX 1).mem)) ∧
    ¬ Val.Skel (.bits 16 0x3C00) .poison := by
  refine ⟨fminmax_skel rfl rfl _ _ _ _ _ _ ?_ rfl, rfl, rfl, rfl, rfl, rfl, ?_⟩
  · exact rfl
  intro h
  simp [Val.Skel, Val.erase] at h

/-- The instance of `rsqrt_skel`: `rsqrt.approx` of 1 on `sX 1`, whose oracle number 0 gives the
word `+0`, which misses the contract, so the fallback 1, and of 4 on `sX 2` with the oracle number
`0x3f000000`, the word of 0.5, which meets it, gives related results, the words of 1 and 0.5. The
twins of its premises that the flags have no `nnan` and no `ninf`: `rsqrt.approx nnan` of -1 gives
`poison`, and of 1 a word; `rsqrt.approx ninf` of `+0` gives `poison`, and of 1 a word. -/
theorem approx_skel :
    Except.Rel (Option.Rel fun r₁ r₂ => Option.Rel Val.Skel r₁.1 r₂.1 ∧ r₁.2 = (sX 1).mem ∧
        r₂.2 = (sX 2).mem)
      (intrinsic (c2 0) (sX 1) {} .rsqrtApprox [.bits 32 0x3f800000])
      (intrinsic (c2 0) { sX 2 with ch := fun _ => 0x3f000000 } {} .rsqrtApprox
        [.bits 32 0x40800000]) ∧
    ((intrinsic (c2 0) (sX 1) {} .rsqrtApprox [.bits 32 0x3f800000]).toOption.bind
      (·.bind (·.1)) |>.bind (·.float? .float)) = (Val.bits 32 0x3f800000).float? .float ∧
    ((intrinsic (c2 0) { sX 2 with ch := fun _ => 0x3f000000 } {} .rsqrtApprox
      [.bits 32 0x40800000]).toOption.bind (·.bind (·.1)) |>.bind (·.float? .float)) =
      (Val.bits 32 0x3f000000).float? .float ∧
    (intrinsic (c2 0) (sX 1) { nnan := true } .rsqrtApprox [.bits 32 0xbf800000]
      matches .ok (some (some .poison, _))) ∧
    (intrinsic (c2 0) (sX 1) { nnan := true } .rsqrtApprox [.bits 32 0x3f800000]
      matches .ok (some (some (.bits _ _), _))) ∧
    (intrinsic (c2 0) (sX 1) { ninf := true } .rsqrtApprox [.bits 32 0]
      matches .ok (some (some .poison, _))) ∧
    (intrinsic (c2 0) (sX 1) { ninf := true } .rsqrtApprox [.bits 32 0x3f800000]
      matches .ok (some (some (.bits _ _), _))) ∧
    ∀ b : BitVec 32, ¬ Val.Skel (.bits 32 b) .poison := by
  refine ⟨rsqrt_skel rfl rfl (c2 0) (c2 0) (sX 1) { sX 2 with ch := fun _ => 0x3f000000 } ?_,
    by decide +kernel, by decide +kernel, by decide +kernel,
    by decide +kernel, by decide +kernel, by decide +kernel, ?_⟩
  · exact rfl
  intro b h
  simp [Val.Skel, Val.erase] at h

/-- The instances of `withAttrs_skel`, with block 1 payload (`skel_pay`): `noundef` on the related
words 1 and 2 on `memX 1` and `memX 2` gives related results, 1 the first, and `nonnull` on `p1`
(the pointer to block 1) on both gives related results. The twin of its premise that no
attribute is a `range` or the values are equal: `range i8 0, 2` gives 1 on the word 1 and `poison`
on the word 2, which are not related. -/
theorem attrs_skel :
    Except.Rel Val.Skel (withAttrs {} (memX 1) (.int 8) [.flag "noundef"] (.bits 8 1))
      (withAttrs {} (memX 2) (.int 8) [.flag "noundef"] (.bits 8 2)) ∧
    withAttrs {} (memX 1) (.int 8) [.flag "noundef"] (.bits 8 1) = .ok (.bits 8 1) ∧
    Except.Rel Val.Skel (withAttrs {} (memX 1) (.ptr 0) [.flag "nonnull"] p1)
      (withAttrs {} (memX 2) (.ptr 0) [.flag "nonnull"] p1) ∧
    withAttrs {} (memX 1) (.int 8) [.range (.int 8) 0 2] (.bits 8 1) = .ok (.bits 8 1) ∧
    withAttrs {} (memX 1) (.int 8) [.range (.int 8) 0 2] (.bits 8 2) = .ok .poison ∧
    ¬ Val.Skel (.bits 8 1) .poison := by
  refine ⟨withAttrs_skel skel_pay.1 _ _ _ ?_ (.inl ?_), rfl,
    withAttrs_skel skel_pay.1 _ _ _ rfl (.inr rfl), rfl, rfl, ?_⟩
  · exact rfl
  · simp [MojoProof.LLVM.Attr.name]
  intro h
  simp [Val.Skel, Val.erase] at h

end MojoProofTest.Skeleton
