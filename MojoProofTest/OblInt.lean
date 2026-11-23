import MojoProof.Sym.Obl

/-!
# Twins of mojo_obl's integer lemmas, on hand-written blocks

In gevm_kernel (MojoProofTest/OblGevm.lean) the premises of mojo_obl's lemmas for `udiv`, `sub`,
`xor`, `ashr`, `select`, `icmp eq` and negative constants are literals or follow from the
launch's facts, so no twin there leaves one of them open. Here each lemma has a block of its own
(a hand-written `Summary` of one to three nodes, as `hand0` in MojoProofTest/Obl.lean), a
valuation at a frame's entry whose registers hold the operands, and a node obligation
(`Cond.ok`) whose proof needs that lemma; every premise mojo_obl needs is in the context except
one of the lemma's, which is behind an irreducible definition, a variable or another term:
mojo_obl leaves the obligation open, as logged, and closes it once the premise is given
(`unfold`, `subst`).

* `udiv_open`: `intBin_udiv_ofNat`'s `0 < b`, behind `Pos`.
* `sub_open`: `intBin_sub_wrap`'s flags without `nuw` and `nsw`, a variable `fl` with
  `fl = {}` (its premises are decided by evaluation, not read from the context).
* `xor_open`: `intBin_xor_ofNat`'s `b < 2 ^ w`, behind `Below32`.
* `ashr_pos_open`, `ashr_neg_open`: the sign of the second operand of the `xor` an `ashr` by 31
  shifts, behind `NonNeg` (`intBin_ashr_xor_pos`) and `Neg` (`intBin_ashr_xor_neg`).
* `select_same_open`: `SNode.eval_select_same`'s operands of one value, two words of `x` and `y`
  with `x = y` behind `Same`, on a condition that is no `decide` (so `SNode.eval_select_word`
  does not apply); the `select`'s value is then an `if` of two values, not a word, and the
  `add` after it is left open.
* `select_word_open`: `SNode.eval_select_word`'s first operand a word of a number, a word `u`
  with `u = BitVec.ofNat 32 x` behind `IsWord`, on an `icmp ult` that omega does not decide; the
  `add` after the `select` is left open.
* `icmp_eq_mod_open`: `SNode.eval_icmp_eq_mod`'s first operand a word of a number, behind
  `IsWord`, with no bound on the operands (so `SNode.eval_icmp_eq_ofNat` does not apply after
  `subst` either).
* `int_negSucc_open`: `SVal.eval_int_negSucc`'s `k < 2 ^ w` for the constant `-(k + 1)`, a
  variable `k` with `k = 31` (its premise is decided by evaluation, as for a literal).

Tests of hand-written blocks, at every context, memory and frame with the stated registers; the
lemmas (MojoProof/Sym/OblLemmas.lean) are for every program.
-/

namespace MojoProofTest.OblInt

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

/-- The block of nodes `ns` with no register, effect or obligation, which returns. -/
def blk (ns : List SNode) : Summary :=
  { nodes := ns, regs := [], effs := [], obls := [], exit := .ret, len := ns.length }

/-- `%0 udiv %1` at width 32. -/
def udivB : Summary := blk [.bin .udiv {} 32 (.reg 0) (.reg 1)]

/-- `0 < y`; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def Pos (y : Nat) : Prop := 0 < y

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) udivB.nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `intBin_udiv_ofNat`'s `0 < b`**: for every context, memory and frame whose
registers `0`, `1` hold the 32-bit words of `x, y < 2 ^ 32` with `0 < y` stated as `Pos y`, the
`udiv` of `udivB` has a value; mojo_obl leaves it open, as logged, and closes it after
`unfold Pos`. -/
theorem udiv_open (c : Ctx) (m : Mem) (f : Frame) (x y : Nat) (hx : x < 2 ^ 32)
    (hy : y < 2 ^ 32) (hp : Pos y) (h0 : f.regs 0 = some (.bits 32 (BitVec.ofNat 32 x)))
    (h1 : f.regs 1 = some (.bits 32 (BitVec.ofNat 32 y))) :
    Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) udivB.nodes)
      (.ok (.node 0)) := by
  mojo_obl
  unfold Pos at hp
  mojo_obl

/-- `%0 sub %1` at width 32 with the flags `fl`. -/
def subB (fl : IntFlags) : Summary := blk [.bin .sub fl 32 (.reg 0) (.reg 1)]

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) (subB fl).nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `intBin_sub_wrap`'s flags**: for every context, memory and frame whose
registers `0`, `1` hold the 32-bit words of `x` and `y`, and flags `fl = {}`, the `sub` of
`subB fl` has a value; mojo_obl, which decides `fl.nuw = false` and `fl.nsw = false` by
evaluation, leaves it open, as logged, and closes it after `subst`. -/
theorem sub_open (c : Ctx) (m : Mem) (f : Frame) (fl : IntFlags) (hfl : fl = {}) (x y : Nat)
    (h0 : f.regs 0 = some (.bits 32 (BitVec.ofNat 32 x)))
    (h1 : f.regs 1 = some (.bits 32 (BitVec.ofNat 32 y))) :
    Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) (subB fl).nodes)
      (.ok (.node 0)) := by
  mojo_obl
  subst hfl
  mojo_obl

/-- `%0 xor %1` at width 32. -/
def xorB : Summary := blk [.bin .xor {} 32 (.reg 0) (.reg 1)]

/-- `y < 2 ^ 32`; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def Below32 (y : Nat) : Prop := y < 2 ^ 32

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) xorB.nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `intBin_xor_ofNat`'s `b < 2 ^ w`**: for every context, memory and frame whose
registers `0`, `1` hold the 32-bit words of `x < 2 ^ 32` and `y` with `y < 2 ^ 32` stated as
`Below32 y`, the `xor` of `xorB` has a value; mojo_obl leaves it open, as logged, and closes it
after `unfold Below32`. -/
theorem xor_open (c : Ctx) (m : Mem) (f : Frame) (x y : Nat) (hx : x < 2 ^ 32)
    (hy : Below32 y) (h0 : f.regs 0 = some (.bits 32 (BitVec.ofNat 32 x)))
    (h1 : f.regs 1 = some (.bits 32 (BitVec.ofNat 32 y))) :
    Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) xorB.nodes)
      (.ok (.node 0)) := by
  mojo_obl
  unfold Below32 at hy
  mojo_obl

/-- `%0 xor %1`, then its `ashr` by 31 (the sign of the `xor`), at width 32. -/
def ashrB : Summary :=
  blk [.bin .xor {} 32 (.reg 0) (.reg 1), .bin .ashr {} 32 (.node 0) (.int 32 (.ofNat 31))]

/-- `2 y < 2 ^ 32` (the word of `y` is non-negative); irreducible, so that mojo_obl does not
find it. -/
@[irreducible] def NonNeg (y : Nat) : Prop := 2 * y < 2 ^ 32

/-- `2 ^ 32 ≤ 2 y` (the word of `y < 2 ^ 32` is negative); irreducible, so that mojo_obl does
not find it. -/
@[irreducible] def Neg (y : Nat) : Prop := 2 ^ 32 ≤ 2 * y

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) ashrB.nodes)
    (Cond.ok (SVal.node 1))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `intBin_ashr_xor_pos`'s sign premise**: for every context, memory and frame
whose registers `0`, `1` hold the 32-bit words of `x` and `y < 2 ^ 32` with `2 x < 2 ^ 32` and
`2 y < 2 ^ 32` stated as `NonNeg y`, the `ashr` of `ashrB` (node 1) has a value; mojo_obl
leaves it open, as logged (neither sign of `y` follows), and closes it after `unfold NonNeg`. -/
theorem ashr_pos_open (c : Ctx) (m : Mem) (f : Frame) (x y : Nat) (hx : 2 * x < 2 ^ 32)
    (hy : y < 2 ^ 32) (hn : NonNeg y) (h0 : f.regs 0 = some (.bits 32 (BitVec.ofNat 32 x)))
    (h1 : f.regs 1 = some (.bits 32 (BitVec.ofNat 32 y))) :
    Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) ashrB.nodes)
      (.ok (.node 1)) := by
  mojo_obl
  unfold NonNeg at hn
  mojo_obl

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) ashrB.nodes)
    (Cond.ok (SVal.node 1))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `intBin_ashr_xor_neg`'s sign premise**: as `ashr_pos_open`, with
`2 ^ 32 ≤ 2 y` stated as `Neg y`; closed after `unfold Neg`. -/
theorem ashr_neg_open (c : Ctx) (m : Mem) (f : Frame) (x y : Nat) (hx : 2 * x < 2 ^ 32)
    (hy : y < 2 ^ 32) (hn : Neg y) (h0 : f.regs 0 = some (.bits 32 (BitVec.ofNat 32 x)))
    (h1 : f.regs 1 = some (.bits 32 (BitVec.ofNat 32 y))) :
    Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) ashrB.nodes)
      (.ok (.node 1)) := by
  mojo_obl
  unfold Neg at hn
  mojo_obl

/-- `select %2, %0, %1` at width 32, then its `add` to `%0`. -/
def selSameB : Summary :=
  blk [.select 32 (.reg 2) (.reg 0) (.reg 1), .bin .add {} 32 (.node 0) (.reg 0)]

/-- `x = y`; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def Same (x y : Nat) : Prop := x = y

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) selSameB.nodes)
    (Cond.ok (SVal.node 1))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `SNode.eval_select_same`'s operands of one value**: for every context, memory
and frame whose registers `0`, `1` hold the 32-bit words of `x` and `y` with `x = y` stated as
`Same x y`, and whose register `2` is the boolean `p`, the `add` of `selSameB` (node 1) has a
value; mojo_obl gives the `select` the value `bif p then … else …`, no word, leaves the `add`
open, as logged, and closes it after `unfold Same` and `subst`. -/
theorem select_same_open (c : Ctx) (m : Mem) (f : Frame) (p : Bool) (x y : Nat)
    (hxy : Same x y) (h0 : f.regs 0 = some (.bits 32 (BitVec.ofNat 32 x)))
    (h1 : f.regs 1 = some (.bits 32 (BitVec.ofNat 32 y))) (h2 : f.regs 2 = some (.ofBool p)) :
    Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) selSameB.nodes)
      (.ok (.node 1)) := by
  mojo_obl
  unfold Same at hxy
  subst hxy
  mojo_obl

/-- `%2 <u %3`, `select` on it of `%0` and `%1`, then the `add` of the `select` to `%1`, at
width 32. -/
def selWordB : Summary :=
  blk [.icmp .ult 32 (.reg 2) (.reg 3), .select 32 (.node 0) (.reg 0) (.reg 1),
    .bin .add {} 32 (.node 1) (.reg 1)]

/-- `u` is the 32-bit word of `x`; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def IsWord (u : BitVec 32) (x : Nat) : Prop := u = BitVec.ofNat 32 x

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) selWordB.nodes)
    (Cond.ok (SVal.node 2))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `SNode.eval_select_word`'s words of numbers**: for every context, memory and
frame whose register `0` holds the word `u`, with `u = BitVec.ofNat 32 x` stated as
`IsWord u x`, and whose registers `1`, `2`, `3` hold the 32-bit words of `y`, `a < 2 ^ 32` and
`b < 2 ^ 32`, the `add` of `selWordB` (node 2) has a value; mojo_obl gives the `select` on the
undecided `a < b` the value `bif decide (a < b) then … else …`, no word, leaves the `add` open,
as logged, and closes it after `unfold IsWord` and `subst`. -/
theorem select_word_open (c : Ctx) (m : Mem) (f : Frame) (u : BitVec 32) (x y a b : Nat)
    (hu : IsWord u x) (ha : a < 2 ^ 32) (hb : b < 2 ^ 32) (h0 : f.regs 0 = some (.bits 32 u))
    (h1 : f.regs 1 = some (.bits 32 (BitVec.ofNat 32 y)))
    (h2 : f.regs 2 = some (.bits 32 (BitVec.ofNat 32 a)))
    (h3 : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 b))) :
    Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) selWordB.nodes)
      (.ok (.node 2)) := by
  mojo_obl
  unfold IsWord at hu
  subst hu
  mojo_obl

/-- `%0 == %1` at width 32. -/
def eqB : Summary := blk [.icmp .eq 32 (.reg 0) (.reg 1)]

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) eqB.nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `SNode.eval_icmp_eq_mod`'s words of numbers**: for every context, memory and
frame whose register `0` holds the word `u`, with `u = BitVec.ofNat 32 x` stated as
`IsWord u x`, and whose register `1` holds the 32-bit word of `y` (no bound on `x` or `y`), the
`icmp eq` of `eqB` has a value; mojo_obl leaves it open, as logged, and closes it after
`unfold IsWord` and `subst`, by `SNode.eval_icmp_eq_mod` (with no bounds,
`SNode.eval_icmp_eq_ofNat` does not apply). -/
theorem icmp_eq_mod_open (c : Ctx) (m : Mem) (f : Frame) (u : BitVec 32) (x y : Nat)
    (hu : IsWord u x) (h0 : f.regs 0 = some (.bits 32 u))
    (h1 : f.regs 1 = some (.bits 32 (BitVec.ofNat 32 y))) :
    Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) eqB.nodes)
      (.ok (.node 0)) := by
  mojo_obl
  unfold IsWord at hu
  subst hu
  mojo_obl

/-- `%0 + (-(k + 1))` at width 32. -/
def negB (k : Nat) : Summary := blk [.bin .add {} 32 (.reg 0) (.int 32 (.negSucc k))]

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) (negB k).nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `SVal.eval_int_negSucc`'s `k < 2 ^ w`**: for every context, memory and frame
whose register `0` holds the 32-bit word of `x`, and `k = 31`, the `add` of `negB k` has a
value; mojo_obl, which decides `k < 2 ^ 32` by evaluation, finds no value for the constant
`-(k + 1)`, leaves the `add` open, as logged, and closes it after `subst`. -/
theorem int_negSucc_open (c : Ctx) (m : Mem) (f : Frame) (k x : Nat) (hk : k = 31)
    (h0 : f.regs 0 = some (.bits 32 (BitVec.ofNat 32 x))) :
    Cond.Holds (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f) (negB k).nodes)
      (.ok (.node 0)) := by
  mojo_obl
  subst hk
  mojo_obl

end MojoProofTest.OblInt
