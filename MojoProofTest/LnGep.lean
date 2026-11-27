import MojoProofTest.GPUProof.ViewWords

/-!
# Layer norm's `getelementptr` on a row of `n` floats, inside and past the row

Layer norm (tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll, the
kernel of block size `B = 128`) computes at :699 the float index `B j + tid` of step `j` and at
:700-703 four `getelementptr inbounds float` by it, before the guard `icmp slt` with `n` (:708)
branches (:709) to the store (:722) or past it. `ln_gep` (MojoProofTest/GPUProof/ViewWords.lean)
gives the pointer at a buffer of `4 B X` bytes. On a row of `n` floats in a buffer of `4 n`
bytes, the threads whose float `B j + tid` is past the row compute a `getelementptr` out of the
buffer. What the semantics gives there (`gepPtr`, MojoProof/Sem/Eval.lean:217-243, the rule at
:240-242; its module docstring :11-20):

* inside the row (`B j + tid < n`), the pointer to the float's first byte (`ln_gep_row`);
* exactly at the row's end (`B j + tid = n`, the offset `4 n`, the block's size), a pointer one
  past the end, unless the block's last address is `2 ^ 64 - 1` (then the `nusw` rule makes it
  poison); the test below evaluates it at one memory;
* past the end of the block (`size < 4 (B j + tid)`), poison, by `inbounds` with a nonzero index
  and an offset outside `[0, size]` (`gep_inbounds_past`, `ln_gep_past`), as LangRef's
  "getelementptr Instruction" says of `inbounds`;
* never a fault: `MojoProof.Sym.gep_buffer_ok` gives a value for every word into a buffer.

So the semantics accepts the step LLVM accepts: no fault at the inactive threads, and the guard
(`ln_words`' `icmp slt`, false there) skips the store, so neither the poison nor the pointer past
the end reaches memory. The step with the guard false, as a run of the symbolic layer, is
MojoProofTest/LnRound.lean's `round_false`.

These are facts about words, not run theorems.
-/

namespace MojoProofTest.LnGep

open _root_.GPUProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.GPUProof.MixedRadix (asg)
open MojoProofTest.GPUProof.ViewStride (lnView)
open MojoProofTest.GPUProof.ViewWords (ln_offAt oneBuf oneBuf_in)

/-- **A `getelementptr inbounds` past its block is poison.** For every layout `l`, memory `M`,
flags `fl` with `inbounds`, element type `src`, block `c` of `M` (`M.blocks c = some blk`),
address space `a` (the block's or the generic space 0), width `w ≤ (l.ptr a).1` and index `K`
with `2 K < 2 ^ w` whose offset `K · l.size src` is past the block's end
(`blk.size < K · l.size src`): the `gep` from `⟨c, 0⟩` by the word of `K` is poison, not a fault
(`gepPtr`, MojoProof/Sem/Eval.lean:240-242: under `inbounds`, a nonzero index and an offset
outside `[0, blk.size]`). -/
theorem gep_inbounds_past {l : Layout} {M : Mem} {fl : GepFlags} {src : Ty} {a c K w : Nat}
    {blk : MojoProof.Sem.Block} (hb : M.blocks c = some blk) (ha : a = blk.space ∨ a = 0)
    (hi : fl.inbounds = true) (hw : w ≤ (l.ptr a).1) (hK : 2 * K < 2 ^ w)
    (hout : blk.size < K * l.size src) :
    gep l M fl src a [.bits w (BitVec.ofNat w K)] (.ptr ⟨c, 0⟩) = .ok .poison := by
  obtain ⟨g, hA⟩ : ∃ g, M.addr l a ⟨c, 0⟩ = .ok g := by
    simp only [Mem.addr, Mem.block, hb, ha, ite_true]
    split <;> exact ⟨_, rfl⟩
  have hti : (BitVec.ofNat w K).toInt = K := BitVec.toInt_ofNat_of_lt hK
  have hMB : M.block ⟨c, 0⟩ = some blk := by simp [Mem.block, hb]
  have hK0 : K ≠ 0 := by
    rintro rfl
    simp at hout
  have hsz : (blk.size : Int) < (K : Int) * (l.size src : Int) := by exact_mod_cast hout
  simp [gep, gepPtr, hw, hti, hA, hMB, gepSteps, gepSteps.into, bind, Except.bind, pure,
    Except.pure, hi, hK0]
  intro h
  omega

/-- **Layer norm's `getelementptr` on a row of `n` floats.** Layer norm (the corpus file) at block
size `B`, for every launch (`lnAdm B` is not needed), thread `t`, step `j < X` (the variable 5),
row length `n` with `2 (4 n) < 2 ^ 64` whose float `B j + tid` is in the row (`B j + tid < n`),
every layout whose floats have 4 bytes and whose address space `a` (0 or the buffer's) has 64-bit
pointers, and every memory in which `y` is a buffer (`Mem.BufferIn`) of at least `4 n` bytes that
fits space `a`: the `getelementptr` of a float from `⟨y, 0⟩` by the 64-bit word of `B j + tid`
(:700) is the pointer to byte `offAt (4 j)` at the key stride 4 of `y`, at all flags: `ln_gep`'s
pointer, at a buffer of the row's `4 n` bytes instead of `4 B X` (`gep_buffer`). A fact about
words, not a run theorem. -/
theorem ln_gep_row (y : Nat) {B : Nat} {σ : Sizes} {L : Launch} {t j : Nat} (hj : j < σ 5)
    {n : Nat} (hk : B * j + (L.env t).sreg .tid .x < n) (hn : 2 * (4 * n) < 2 ^ 64) {l : Layout}
    {M m : Mem} {fl : GepFlags} {s a size al : Nat} {ow : Owner} {wr : Bool}
    (hMb : M.blocks = m.blocks) (hB : m.BufferIn s y size al ow wr) (ha' : a = 0 ∨ a = s)
    (hF : ∃ blk, m.blocks y = some blk ∧ (if a = s then blk.addr else blk.gaddr) + size ≤
      2 ^ (l.ptr a).1)
    (hp : (l.ptr a).1 = 64) (h4 : l.size (.fp .float) = 4) (hsz : 4 * n ≤ size) :
    gep l M fl (.fp .float) a [.bits 64 (BitVec.ofNat 64 (B * j + (L.env t).sreg .tid .x))]
        (.ptr ⟨y, 0⟩) =
      .ok (.ptr ⟨y, ((lnView y B).offAt (fun _ => 4) σ L (sig.group L 0 t) (4 * j) : Int)⟩) := by
  have h0 := ln_offAt y B L t hj (b := 0) (by decide)
  simp only [Nat.add_zero] at h0
  rw [h0]
  have e := gep_buffer (fl := fl) (src := .fp .float) (K := B * j + (L.env t).sreg .tid .x)
    (w := 64) hMb hB ha' hF (by omega) (by omega) (by rw [h4, hp]; omega) (by rw [h4]; omega)
  rw [h4, Nat.mul_comm _ 4] at e
  exact e

/-- **Layer norm's `getelementptr` past the row is poison.** Layer norm (the corpus file), for
every launch (`lnAdm` is not needed), thread `t`, index word `i` (the loop index of the step,
:679) with `2 (i + tid) < 2 ^ 64`, every layout whose floats have 4 bytes and whose address space
`a` has 64-bit pointers, flags with `inbounds` (the IR's, :700) and every memory in which block
`y`, in space `a` or read through the generic space 0, has fewer than `4 (i + tid)` bytes (at a
buffer of exactly the row's `4 n` bytes: the float `i + tid` is past `n`): the `getelementptr` of
a float from `⟨y, 0⟩` by the word of `i + tid` is poison (`gep_inbounds_past`). The guard is
false there (`ln_words`), so the poison is not stored through. A fact about words, not a run
theorem. -/
theorem ln_gep_past {L : Launch} {t i y a : Nat} {l : Layout} {M : Mem} {fl : GepFlags}
    {blk : MojoProof.Sem.Block} (hb : M.blocks y = some blk) (ha' : a = blk.space ∨ a = 0)
    (hi : fl.inbounds = true) (hp : (l.ptr a).1 = 64) (h4 : l.size (.fp .float) = 4)
    (hk : 2 * (i + (L.env t).sreg .tid .x) < 2 ^ 64)
    (hout : blk.size < 4 * (i + (L.env t).sreg .tid .x)) :
    gep l M fl (.fp .float) a [.bits 64 (BitVec.ofNat 64 (i + (L.env t).sreg .tid .x))]
      (.ptr ⟨y, 0⟩) = .ok .poison := by
  exact gep_inbounds_past hb ha' hi (by omega) hk (by rw [h4, Nat.mul_comm]; exact hout)

/-- The kernel of block size 128 (the IR's), one block of 128 threads, `n = 300` and `X = 3`, step
2 (the index word `256`), the default layout (64-bit pointers in space 0, 4-byte floats), the
IR's flags (`inbounds`) and the buffer `oneBuf` of exactly the row's `4 · 300` bytes: thread 43
(float 299, in the row) has `ln_gep_row`'s pointer, byte `4 · 299`; thread 44 (float 300, the
row's end) has the pointer one past the end, byte `1200`; thread 45 (float 301) has poison
(`ln_gep_past`). -/
example :
    gep {} (oneBuf (4 * 300)) { inbounds := true } (.fp .float) 0
        [.bits 64 (BitVec.ofNat 64 (128 * 2 + ((launch2 1 1 128 1).env 43).sreg .tid .x))]
        (.ptr ⟨1, 0⟩) = .ok (.ptr ⟨1, 4 * 299⟩) ∧
      gep {} (oneBuf (4 * 300)) { inbounds := true } (.fp .float) 0
        [.bits 64 (BitVec.ofNat 64 (128 * 2 + ((launch2 1 1 128 1).env 44).sreg .tid .x))]
        (.ptr ⟨1, 0⟩) = .ok (.ptr ⟨1, 1200⟩) ∧
      gep {} (oneBuf (4 * 300)) { inbounds := true } (.fp .float) 0
        [.bits 64 (BitVec.ofNat 64 (128 * 2 + ((launch2 1 1 128 1).env 45).sreg .tid .x))]
        (.ptr ⟨1, 0⟩) = .ok .poison := by
  refine ⟨?_, rfl, ln_gep_past (L := launch2 1 1 128 1) (t := 45) rfl (.inr rfl) rfl rfl
    rfl (by decide) (by decide)⟩
  have e := ln_gep_row 1 (B := 128) (σ := asg [0, 0, 0, 0, 128, 3]) (L := launch2 1 1 128 1)
    (t := 43) (j := 2) (by decide) (n := 300) (by decide) (by decide) (l := {})
    (M := oneBuf (4 * 300)) (fl := { inbounds := true }) (size := 4 * 300) rfl (oneBuf_in _)
    (.inl rfl) ⟨_, rfl, by decide⟩ rfl rfl (by decide)
  rw [e]
  rfl

end MojoProofTest.LnGep
