import MojoProofTest.SymSeg
import MojoProof.Sym.OblHave
import MojoProof.Sym.LoopFacts
import MojoProof.LLVM.Family

/-!
# Layer norm's loop: one round with the guard true and one with the guard false

Tests of one program, layer norm at block size 128 (MojoProofTest/SymSeg.lean's `ln`,
tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll): the loop that
writes the normalized row, header `%469` (:677-690), its body `%483`, `%484` (:692-709), the
guarded store's blocks `%495`, `%496` (:711-722), the joins `%529`, `%531`, `%532` (:763-772) and
the exit `%482` (:692-693). At round `j` of a thread, the loop index `%471` is `128 j`, the float
index `%485` (:699) is `128 j + tid` and the guard `%494` (:708) is `128 j + tid < n`, `n` the row
length `%65`.

* `hdr`, `b482`, `b483`, `b484`, `b495`, `b496`, `b529`, `b531`, `b532`: the blocks' summaries.
* `lnT`, `lnF`: the loop with the guard true (through the store `%496`) and false (through
  `%531`, no store); both have the exit `%482`.
* `eval_xor_true`, `eval_or_false`, `eval_sminmax`, `smin_sub_one`: node evaluations `mojo_obl`
  does not make (the header's `xor` and `or` of booleans, `llvm.smin` and `llvm.smax`).
* `round_false`: the round with the guard false runs (`RoundWith`), for every index, thread and
  row length with the guard false: the step of an inactive thread, whose `getelementptr`s
  (:700-703) evaluate (MojoProofTest/LnGep.lean) and whose store is skipped.
* `round_true`: the round with the guard true runs, for every index, thread and row length with
  the guard true, from buffers holding the row `X`, the weight `G` and the bias `Bt`.
* `lnFam`: the family of the four corpus files ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}
  in the loop, by `mojo_family`: `ln.prog` with the step constant of `%473` (:681) as the block
  size `B` (`lnFam.prog_corpus`: at 128 it is `ln.prog`). In the loop's blocks (:677-772) the four
  files differ only in that constant; `hdrB`, `lnTB`, `lnFB` are the header's summary and the two
  rounds at `B` (`hdrB_128`, `lnTB_128`, `lnFB_128`: at 128 they are `hdr`, `lnT`, `lnF`).
* `round_falseB`, `round_trueB`: `round_false` and `round_true` at every block size
  `B ≤ 2 ^ 32`, on `ln.prog` with the function `lnFam.fn B`; `round_false` and `round_true` are
  their instances at 128.

These are run theorems' premises: `Block.sound_edge` runs a round from `RoundWith`. The run of
the loop over its rounds, for every row length, is MojoProofTest/LnRun.lean's `run`.
-/

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymSeg
open FloatLib.Floats.Formats.BinaryInterchange

namespace MojoProofTest.LnRound

/-- Layer norm's header `%469` from statement 3, after its `phi`s (:681-690): the step `add`,
its overflow test, the exit test `icmp sge` with `n`, the `xor` and `or` of the exit flag, the
`select`s and the branch to `%482` or `%483`. -/
sym_summary hdr := ln.prog ln.fn_0 ln.fn_0.b_43.label 3

/-- Layer norm's `%482`: `br label %534`, out of the loop (:692-693). -/
sym_summary b482 := ln.prog ln.fn_0 ln.fn_0.b_44.label 0

/-- Layer norm's `%483`: `br label %484` (:695-696). -/
sym_summary b483 := ln.prog ln.fn_0 ln.fn_0.b_45.label 0

/-- Layer norm's `%484` (:698-709): the float index `add`, the four `getelementptr inbounds`, the
`sub`, `llvm.smin`, `llvm.smax`, the two tests and the branch on the guard `%494`. -/
sym_summary b484 := ln.prog ln.fn_0 ln.fn_0.b_46.label 0

/-- Layer norm's `%495`: the branch on `%493` to `%496` or `%504` (:711-712). -/
sym_summary b495 := ln.prog ln.fn_0 ln.fn_0.b_47.label 0

/-- Layer norm's `%529` from statement 1, after its `phi`: `br label %532` (:763-765). -/
sym_summary b529 := ln.prog ln.fn_0 ln.fn_0.b_55.label 1

/-- Layer norm's `%531`: `br label %532` (:767-768). -/
sym_summary b531 := ln.prog ln.fn_0 ln.fn_0.b_56.label 0

/-- Layer norm's `%532` from statement 1, after its `phi`: `br label %469` (:770-772). -/
sym_summary b532 := ln.prog ln.fn_0 ln.fn_0.b_57.label 1

/-- Layer norm's `%496` with `fmul contract` in the fragment (`summarizeC`, :714-722): the three
loads, `fsub`, two `fmul` and `fadd contract`, the store through `%486` and the branch to `%529`.
A test definition. -/
def b496 : Summary := (summarizeC ln.prog ln.fn_0 ln.fn_0.b_48.label 0).getD default

/-- Layer norm's loop with the guard false: `%469` from statement 3, `%483`, `%484`, `%531`,
`%532`; the path out `%482`. A test definition. -/
def lnF : LoopSeg := ⟨ln.fn_0.b_43.label, 3, hdr.obls, hdr,
  [(ln.fn_0.b_45.label, b483.obls, b483), (ln.fn_0.b_46.label, b484.obls, b484),
   (ln.fn_0.b_56.label, b531.obls, b531), (ln.fn_0.b_57.label, b532.obls, b532)],
  [(ln.fn_0.b_44.label, b482.obls, b482)], []⟩

/-- Layer norm's loop with the guard true: `%469` from statement 3, `%483`, `%484`, `%495`,
`%496`, `%529`, `%532`; the path out `%482`. A test definition. -/
def lnT : LoopSeg := ⟨ln.fn_0.b_43.label, 3, hdr.obls, hdr,
  [(ln.fn_0.b_45.label, b483.obls, b483), (ln.fn_0.b_46.label, b484.obls, b484),
   (ln.fn_0.b_47.label, b495.obls, b495), (ln.fn_0.b_48.label, b496.obls, b496),
   (ln.fn_0.b_55.label, b529.obls, b529), (ln.fn_0.b_57.label, b532.obls, b532)],
  [(ln.fn_0.b_44.label, b482.obls, b482)], []⟩

/-- Layer norm's last loop at every block size `B` (the corpus files
ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}, whose loop blocks :677-772 differ only in the
step `%473 = add i64 %471, B`, :681): the bs128 file's program with that constant as `B`. -/
mojo_family lnFam := ln.prog 0 with B at "%473"

/-- Layer norm's header `%469` from statement 3 at block size `B` (:681-690): `hdr` with its first
node, the step `%473 = add i64 %471, B` (:681), at `B`, for every `B`; the summary of
`lnFam.fn B`'s header (MojoProofTest/LnFamily.lean evaluates it at 64, 256 and 1024 at the
corpus files) and `hdr` at 128 (`hdrB_128`). A test definition. -/
def hdrB (B : Nat) : Summary :=
  { hdr with nodes := hdr.nodes.set 0 (.bin .add {} 64 (.reg 476) (.int 64 (Int.ofNat B))) }

/-- `hdrB` at block size 128 is the bs128 file's header summary `hdr`. By `decide +kernel`. -/
theorem hdrB_128 : hdrB 128 = hdr := by decide +kernel

/-- Layer norm's loop with the guard true at block size `B`, for every `B`: `lnT` with the header
`hdrB B`; its other blocks (:692-772) are the same at every block size of the family. A test
definition. -/
def lnTB (B : Nat) : LoopSeg := { lnT with H := hdrB B }

/-- Layer norm's loop with the guard false at block size `B`, for every `B`: `lnF` with the header
`hdrB B`, and the same path out `%482`. A test definition. -/
def lnFB (B : Nat) : LoopSeg := { lnF with H := hdrB B }

/-- `lnTB` at block size 128 is `lnT`. -/
theorem lnTB_128 : lnTB 128 = lnT := congrArg (fun H => { lnT with H := H }) hdrB_128

/-- `lnFB` at block size 128 is `lnF`. -/
theorem lnFB_128 : lnFB 128 = lnF := congrArg (fun H => { lnF with H := H }) hdrB_128

/-- The `xor` of a boolean node with `true` (the header's `%478`, :685) is its negation, for every
valuation and node values. -/
theorem eval_xor_true {V : Valuation} {vs : List (Except Fault Val)} {a : SVal} {p : Bool}
    (ha : a.eval V vs = .ok (.ofBool p)) :
    (SNode.bin .xor {} 1 a (.int 1 1)).eval V vs = .ok (.ofBool (!p)) :=
  SNode.eval_bin (x := if p then 1 else 0) ha rfl (by cases p <;> rfl)

/-- The `or` of `false` with a boolean node (the header's `%479`, :687) is the node, for every
valuation and node values. -/
theorem eval_or_false {V : Valuation} {vs : List (Except Fault Val)} {a b : SVal} {q : Bool}
    (ha : a.eval V vs = .ok (.ofBool false)) (hb : b.eval V vs = .ok (.ofBool q)) :
    (SNode.bin .or {} 1 a b).eval V vs = .ok (.ofBool q) :=
  SNode.eval_bin (x := 0) (y := if q then 1 else 0) ha hb (by cases q <;> rfl)

/-- The signed `llvm.smin` (`mx = false`) or `llvm.smax` (`mx = true`) node of two words (:705,
:706) is `intMinMax`'s choice, for every valuation, node values, width and words. -/
theorem eval_sminmax {V : Valuation} {vs : List (Except Fault Val)} {mx : Bool} {a b : SVal}
    {w : Nat} {x y : BitVec w} (ha : a.eval V vs = .ok (.bits w x))
    (hb : b.eval V vs = .ok (.bits w y)) :
    (SNode.minmax true mx a b).eval V vs =
      .ok (.bits w (if (x.slt y == mx) = true then y else x)) := by
  simp only [SNode.eval, ha, hb, bind, Except.bind, intMinMax, strict2, dite_true, BitVec.cast_eq]
  rfl

/-- The `llvm.smin` with 1 (:705) of the word `n - k` (:704) is 1 when `k < n`, for every `n`
and `k` with doubles below `2 ^ 64`. -/
theorem smin_sub_one {n k : Nat} (hn : 2 * n < 2 ^ 64) (hk : 2 * k < 2 ^ 64) (hkn : k < n) :
    (if ((BitVec.ofNat 64 ((2 ^ 64 - k % 2 ^ 64 + n) % 2 ^ 64)).slt (BitVec.ofInt 64 1) ==
        false) = true then BitVec.ofInt 64 1
      else BitVec.ofNat 64 ((2 ^ 64 - k % 2 ^ 64 + n) % 2 ^ 64)) = BitVec.ofNat 64 1 := by
  have hd : (BitVec.ofNat 64 ((2 ^ 64 - k % 2 ^ 64 + n) % 2 ^ 64)).toNat =
      (2 ^ 64 - k + n) % 2 ^ 64 := by
    rw [BitVec.toNat_ofNat, Nat.mod_mod, Nat.mod_eq_of_lt (by omega : k < 2 ^ 64)]
  have hs1 : (BitVec.ofNat 64 ((2 ^ 64 - k % 2 ^ 64 + n) % 2 ^ 64)).slt (BitVec.ofInt 64 1) =
      false := by
    rw [show BitVec.ofInt 64 1 = BitVec.ofNat 64 1 by decide]
    simp only [BitVec.slt, BitVec.toInt_eq_toNat_cond, hd, BitVec.toNat_ofNat]
    split_ifs <;> simp <;> omega
  rw [hs1]
  rfl

/-- **The round with the guard false runs** (the step of an inactive thread). Layer norm's last
loop (the corpus files ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size
`B ≤ 2 ^ 32` (so the step `i + B` of :681 has no signed overflow, :682), for every context (so
every launch and thread) of the bs128 file's program `ln.prog` (its layout is the four files':
MojoProofTest/LnFamily.lean) and valuation `W` of the family's function `lnFam.fn B` at the
header `%469` after its `phi`s, with loop index `%471` the word of `i`, `%472` zero, `%470` any
value, `tid` the word of `t < 1024`, the row length `%65` the word of `n < 2 ^ 32` and the
pointers `%466` (`y`, the output), `%467` (`g`), `%468` (`b`) and `%70` (`x`) to buffers of
`4 n` bytes, with `i < n ≤ i + t` (the header goes on, the guard :708 is
false): the premises of the round on the path `%469`, `%483`, `%484`, `%531`, `%532` back to
`%469` hold (`RoundWith`, `lnFB B`; `Block.sound_edge` runs it). The `getelementptr`s at :700-703
by `i + t ≥ n` evaluate (a pointer at or past the row's end, or poison: MojoProofTest/LnGep.lean),
not a fault; the path has no store. A run theorem's premise (IR :677-772). -/
theorem round_falseB (B n t i y g b x : Nat) (W : Valuation) (v : Val)
    (hP : W.ctx.prog = ln.prog) (hfn : W.fn = lnFam.fn B)
    (h476 : W.regs 476 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h478 : W.regs 478 = some (.bits 64 (BitVec.ofNat 64 0)))
    (h474 : W.regs 474 = some v)
    (h24 : W.regs 24 = some (.bits 64 (BitVec.ofNat 64 t)))
    (h67 : W.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h468 : W.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : W.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : W.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : W.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby : W.mem.Buffer y (n * 4) 4 true) (hbg : W.mem.Buffer g (n * 4) 4 false)
    (hbb : W.mem.Buffer b (n * 4) 4 false) (hbx : W.mem.Buffer x (n * 4) 4 false)
    (ht : t < 1024) (hn : n < 2 ^ 32) (hBs : B ≤ 2 ^ 32) (hi : i < n) (hg : n ≤ i + t) :
    RoundWith true (lnFB B).h (lnFB B).p (lnFB B).dh (lnFB B).H (lnFB B).B W := by
  obl_have e3 : (vals W (lnFB B).H.nodes)[3]?, e4 : (vals W (lnFB B).H.nodes)[4]?
  have e5 : (vals W (lnFB B).H.nodes)[5]? = some (.ok (.ofBool false)) :=
    vals_getElem?_eval rfl (eval_xor_true (SVal.eval_node_take (by decide) e4))
  have e6 : (vals W (lnFB B).H.nodes)[6]? = some (.ok (.ofBool (decide (n ≤ i)))) :=
    vals_getElem?_eval rfl (eval_or_false (SVal.eval_node_take (by decide) e5)
      (SVal.eval_node_take (by decide) e3))
  obl_have f5 : (vals (Valuation.intoWith true (Valuation.intoWith true W (lnFB B).h (lnFB B).H)
    ln.fn_0.b_45.label b483) b484.nodes)[5]?
  have f6 := vals_getElem?_eval (j := 6) rfl
    (eval_sminmax (mx := false) (SVal.eval_node_take (by decide) f5) rfl)
  have f7 := vals_getElem?_eval (j := 7) rfl
    (eval_sminmax (mx := true) (SVal.eval_node_take (by decide) f6) rfl)
  have f8 := vals_getElem?_eval (j := 8) rfl
    (SNode.eval_icmp (p := .eq) (SVal.eval_node_take (by decide) f6) rfl)
  mojo_obl

/-- **The round with the guard false runs** (the step of an inactive thread). Layer norm (the
corpus file) at block size 128, for every context (so every launch and thread) and valuation `W`
of the program at the header `%469` after its `phi`s, with loop index `%471` the word of `i`,
`%472` zero, `%470` any value, `tid` the word of `t < 1024`, the row length `%65` the word of
`n < 2 ^ 32` and the pointers `%466` (`y`, the output), `%467` (`g`), `%468` (`b`) and `%70`
(`x`) to buffers of `4 n` bytes, with `i < n ≤ i + t` (the header goes on, the guard :708 is
false): the premises of the round on the path `%469`, `%483`, `%484`, `%531`, `%532` back to
`%469` hold (`RoundWith`, `lnF`; `Block.sound_edge` runs it). The `getelementptr`s at :700-703 by
`i + t ≥ n` evaluate (a pointer at or past the row's end, or poison: MojoProofTest/LnGep.lean),
not a fault; the path has no store. A run theorem's premise (IR :677-772); `round_falseB` at
128. -/
theorem round_false (n t i y g b x : Nat) (W : Valuation) (v : Val)
    (hP : W.ctx.prog = ln.prog) (hfn : W.fn = ln.fn_0)
    (h476 : W.regs 476 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h478 : W.regs 478 = some (.bits 64 (BitVec.ofNat 64 0)))
    (h474 : W.regs 474 = some v)
    (h24 : W.regs 24 = some (.bits 64 (BitVec.ofNat 64 t)))
    (h67 : W.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h468 : W.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : W.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : W.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : W.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby : W.mem.Buffer y (n * 4) 4 true) (hbg : W.mem.Buffer g (n * 4) 4 false)
    (hbb : W.mem.Buffer b (n * 4) 4 false) (hbx : W.mem.Buffer x (n * 4) 4 false)
    (ht : t < 1024) (hn : n < 2 ^ 32) (hi : i < n) (hg : n ≤ i + t) :
    RoundWith true lnF.h lnF.p lnF.dh lnF.H lnF.B W := by
  rw [← lnFB_128]
  exact round_falseB 128 n t i y g b x W v hP
    (hfn.trans lnFam.prog_corpus.2.symm) h476 h478 h474 h24 h67 h468 h469 h470 h72 hby hbg hbb
    hbx ht hn (by omega) hi hg

/-- **The round with the guard true runs.** Layer norm's last loop (the corpus files
ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B ≤ 2 ^ 32` (the step
`i + B` of :681 has no signed overflow, :682), for every context (so every launch and thread) of
the bs128 file's program `ln.prog` and valuation `W` of the family's function `lnFam.fn B` at the
header `%469` after
its `phi`s, with `round_falseB`'s registers, the mean `%460` and the inverse deviation `%464`
binary32 `mu` and `rs` with no recorded product, the four buffers of `4 n` bytes that fit, `x`,
`g` and `b` holding the rows `X`, `G` and `Bt` (row-major binary32), `t < 1024`, `n < 2 ^ 32` and
`i + t < n` (the guard :708 and the second test :707 are true): the premises of the round on the
path `%469`, `%483`, `%484`, `%495`, `%496`, `%529`, `%532` back to `%469` hold (`RoundWith`,
`lnTB B`), the three loads (:715-717) and the store of `%503` at `y`'s float `i + t` (:722)
included. A run theorem's premise (IR :677-772); the stored value is the IR's `%503`, not
computed here, and the mean and inverse deviation are given registers. -/
theorem round_trueB (B n t i y g b x : Nat) (W : Valuation)
    (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]) (mu rs : Model FloatTy.float.fmt)
    (hP : W.ctx.prog = ln.prog) (hfn : W.fn = lnFam.fn B)
    (h476 : W.regs 476 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h478 : W.regs 478 = some (.bits 64 (BitVec.ofNat 64 0)))
    (h24 : W.regs 24 = some (.bits 64 (BitVec.ofNat 64 t)))
    (h67 : W.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : W.regs 462 = some (.ofFloat .float mu)) (h466 : W.regs 466 = some (.ofFloat .float rs))
    (hq462 : W.prods 462 = none) (hq466 : W.prods 466 = none)
    (h468 : W.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : W.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : W.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : W.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby : W.mem.Buffer y (n * 4) 4 true) (hbg : W.mem.Buffer g (n * 4) 4 false)
    (hbb : W.mem.Buffer b (n * 4) 4 false) (hbx : W.mem.Buffer x (n * 4) 4 false)
    (hfy : W.mem.Fits ln.prog.layout y (n * 4))
    (hfg : W.mem.Fits ln.prog.layout g (n * 4))
    (hfb : W.mem.Fits ln.prog.layout b (n * 4))
    (hfx : W.mem.Fits ln.prog.layout x (n * 4))
    (hX : W.mem.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : W.mem.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : W.mem.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt)
    (ht : t < 1024) (hn : n < 2 ^ 32) (hBs : B ≤ 2 ^ 32) (hg : i + t < n) :
    RoundWith true (lnTB B).h (lnTB B).p (lnTB B).dh (lnTB B).H (lnTB B).B W := by
  obl_have e3 : (vals W (lnTB B).H.nodes)[3]?, e4 : (vals W (lnTB B).H.nodes)[4]?
  have e5 : (vals W (lnTB B).H.nodes)[5]? = some (.ok (.ofBool false)) :=
    vals_getElem?_eval rfl (eval_xor_true (SVal.eval_node_take (by decide) e4))
  have e6 : (vals W (lnTB B).H.nodes)[6]? = some (.ok (.ofBool (decide (n ≤ i)))) :=
    vals_getElem?_eval rfl (eval_or_false (SVal.eval_node_take (by decide) e5)
      (SVal.eval_node_take (by decide) e3))
  obl_have f5 : (vals (Valuation.intoWith true (Valuation.intoWith true W (lnTB B).h (lnTB B).H)
    ln.fn_0.b_45.label b483) b484.nodes)[5]?
  have f6 : (vals (Valuation.intoWith true (Valuation.intoWith true W (lnTB B).h (lnTB B).H)
      ln.fn_0.b_45.label b483) b484.nodes)[6]? = some (.ok (.bits 64 (BitVec.ofNat 64 1))) := by
    refine vals_getElem?_eval (j := 6) rfl
      ((eval_sminmax (mx := false) (SVal.eval_node_take (by decide) f5) rfl).trans ?_)
    rw [smin_sub_one (by omega) (by omega) hg]
  mojo_obl

/-- **The round with the guard true runs.** Layer norm (the corpus file) at block size 128, for
every context (so every launch and thread) and valuation `W` of the program at the header `%469`
after its `phi`s, with `round_false`'s registers, the mean `%460` and the inverse deviation
`%464` binary32 `mu` and `rs` with no recorded product, the four buffers of `4 n` bytes that fit,
`x`, `g` and `b` holding the rows `X`, `G` and `Bt` (row-major binary32), `t < 1024`,
`n < 2 ^ 32` and `i + t < n` (the guard :708 and the second test :707 are true): the premises of
the round on the path `%469`, `%483`, `%484`, `%495`, `%496`, `%529`, `%532` back to `%469`
hold (`RoundWith`, `lnT`), the three loads (:715-717) and the store of `%503` at `y`'s float
`i + t` (:722) included. A run theorem's premise (IR :677-772); the stored value is the IR's
`%503`, not computed here. `round_trueB` at 128. -/
theorem round_true (n t i y g b x : Nat) (W : Valuation)
    (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]) (mu rs : Model FloatTy.float.fmt)
    (hP : W.ctx.prog = ln.prog) (hfn : W.fn = ln.fn_0)
    (h476 : W.regs 476 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h478 : W.regs 478 = some (.bits 64 (BitVec.ofNat 64 0)))
    (h24 : W.regs 24 = some (.bits 64 (BitVec.ofNat 64 t)))
    (h67 : W.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : W.regs 462 = some (.ofFloat .float mu)) (h466 : W.regs 466 = some (.ofFloat .float rs))
    (hq462 : W.prods 462 = none) (hq466 : W.prods 466 = none)
    (h468 : W.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : W.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : W.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : W.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby : W.mem.Buffer y (n * 4) 4 true) (hbg : W.mem.Buffer g (n * 4) 4 false)
    (hbb : W.mem.Buffer b (n * 4) 4 false) (hbx : W.mem.Buffer x (n * 4) 4 false)
    (hfy : W.mem.Fits ln.prog.layout y (n * 4)) (hfg : W.mem.Fits ln.prog.layout g (n * 4))
    (hfb : W.mem.Fits ln.prog.layout b (n * 4)) (hfx : W.mem.Fits ln.prog.layout x (n * 4))
    (hX : W.mem.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : W.mem.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : W.mem.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt)
    (ht : t < 1024) (hn : n < 2 ^ 32) (hg : i + t < n) :
    RoundWith true lnT.h lnT.p lnT.dh lnT.H lnT.B W := by
  rw [← lnTB_128]
  exact round_trueB 128 n t i y g b x W X G Bt mu rs hP
    (hfn.trans lnFam.prog_corpus.2.symm) h476 h478 h24 h67 h462 h466 hq462 hq466 h468 h469 h470
    h72 hby hbg hbb hbx hfy hfg hfb hfx hX hG hB ht hn (by omega) hg

end MojoProofTest.LnRound
