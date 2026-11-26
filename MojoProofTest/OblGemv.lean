import MojoProofTest.SymGemvTail
import MojoProof.Sym.OblHave
import MojoProofTest.KernelRfl
import MojoProofTest.OblGevm
import MojoProofTest.Obl

/-!
# mojo_obl on gemv_kernel's loop at every `K`

gemv_kernel (`gemv` of MojoProofTest/SymLane.lean, the corpus file
gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll) multiplies the
row-major `M × K` matrix `A` of binary32 (`%1`) by the vector `v` of `K` binary32 (`%2`) into
`y` (`%0`), one warp per row. From statement 41 of the entry block `%6` (`%36 = bitcast <2 x i32>
%35 to i64`, the row word `r`), the thread computes the output pointer `%37`, the row's offset
`%38 = r K`, the lane `%40 = sext laneid`, lane 0's flag `%41` and the row guard `%42 = r ≥ M`,
and goes to `%44` when `r < M`. `%44` computes the trip count `%53 = ⌈K / 32⌉`; the loop at the
header `%54` (`%55` the round `i`, `%56` the sum) runs `%60`, which computes the position
`%65 = 32 i + l` and the addresses `%66` (`v`) and `%68` (`A`, element `r K + 32 i + l`), and
goes through the arm `%70` (the two loads, `fmul contract`, `fadd contract`) when `%65 < K`, else
through the arm `%75` (nothing), to the latch `%76`. The loop's blocks and paths are
MojoProofTest/SymGemvTail.lean's (`gC`, `gB`, `loopA` through `%70`, `loopB` through `%75`).

Registers: `%k` is register `k` for `k ≤ 42`; `%53` (the trip count) is 54, `%55` (the round) 58,
`%56` (the sum) 60 and `%79` (`%78`'s `phi`) 80 (`regs_named`).

* `row_node`: node 0 of `%6` from statement 41, the `bitcast` of the vector `%35` of the row
  word's halves to `i64`, is the row word (`castV_join`), by hand: mojo_obl takes no vector
  `bitcast`.
* `entry_edge`: mojo_obl proves the premises of `%6` from statement 41 and of `%44`, and their
  edge into the header `%54` at position 2 (`EdgeWith true`), at every thread of every valid
  launch and every row `r < M`, with `M, K < 2 ^ 31` and the output buffer of `M` floats.
* `entry_regs`: the header's registers after that edge by `obl_have`: the round 0, the sum `+0`
  with no recorded product, the trip count `⌈K / 32⌉`, the row's offset `r K`, the lane, lane
  0's flag, the output pointer and `K`, on the same memory.
* `entry_open`: the twin of `entry_edge` at the branch of `%6`, with `r < M` behind the
  irreducible `MojoProofTest.Obl.Below`: the direction of the branch is left open, as logged.
* `roundA`: mojo_obl proves the premises of round `i` through `%70` (`RoundWith true` of `loopA`)
  for every `K < 2 ^ 31`, `M` with `M K < 2 ^ 61`, row `r < M`, lane `l < 32` and round
  `i < ⌈K / 32⌉` with `32 i + l < K`: the header's compare, `%60`'s `select`, index arithmetic,
  addresses (`gep_buffer`, `gep_buffer2`) and guard, the loads of `A (r, 32 i + l)` and
  `v (32 i + l)`, the `fmul contract` and `fadd contract`, and the latch's `phi`.
* `roundB`: the same for a round through `%75` (`loopB`), with `32 i + l ≥ K`, at every `M` and
  `r`: the addresses are past the buffers and not loaded (`gep_buffer_ok`).
* `arm_open`, `skip_open`: the twins at `%60`'s branch, with `32 i + l < K` (`roundA`'s) and
  `K ≤ 32 i + l` (`roundB`'s) behind irreducible definitions: the direction is left open, as
  logged.
* `matrix_open`: the twin of `roundA` at the load `%71`, with `M K < 2 ^ 61` behind an
  irreducible definition: `gep_buffer2` does not apply to `%68`, so the load has no address.

Tests of one program, gemv_kernel float32 `b79a852b`, for every launch, thread, row, lane and
buffers with the stated premises; the lemmas they use (MojoProof/Sym/OblLemmas.lean) are for every
program. MojoProofTest/GemvLoop.lean runs the thread through the loop with them.
-/

namespace MojoProofTest.OblGemv

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.SymGemvTail
open FloatLib.Floats.Formats.BinaryInterchange

/-- **The register numbers of the loop's registers**: `%36`, `%37`, `%38`, `%40`, `%41` are
registers 36, 37, 38, 40 and 41, the trip count `%53` is 54, the round `%55` 58, the sum `%56` 60
and `%78`'s `phi` `%79` 80. -/
theorem regs_named : gemv.fn_0.names[36]? = some "36" ∧ gemv.fn_0.names[37]? = some "37" ∧
    gemv.fn_0.names[38]? = some "38" ∧ gemv.fn_0.names[40]? = some "40" ∧
    gemv.fn_0.names[41]? = some "41" ∧ gemv.fn_0.names[54]? = some "53" ∧
    gemv.fn_0.names[58]? = some "55" ∧ gemv.fn_0.names[60]? = some "56" ∧
    gemv.fn_0.names[80]? = some "79" := by
  decide +kernel

/-- **The row word `%36`**: for every context, step count, memory, frame `f` of `gemv`'s function
and row `r` whose `%35` is the vector of the two 32-bit halves of `r`'s 64-bit word (low half
first), node 0 of `%6` from statement 41 (`%36 = bitcast <2 x i32> %35 to i64`) is `r`'s 64-bit
word (`SNode.eval_castAt`, `castV_join` at `n = 2`, `w = 32`). -/
theorem row_node (c : Ctx) (s : Nat) (m : Mem) (f : Frame) (hf : f.fn = gemv.fn_0) (r : Nat)
    (h35 : f.regs 35 = some (.vec [.bits 32 ((BitVec.ofNat 64 r).extractLsb' 0 32),
      .bits 32 ((BitVec.ofNat 64 r).extractLsb' 32 32)])) :
    (vals (Valuation.entry c s m f) (gC 6 41).nodes)[0]? =
      some (.ok (.bits 64 (BitVec.ofNat 64 r))) := by
  have hs : (Valuation.entry c s m f).stmt 6 41 =
      some ⟨some 36, .cast .bitcast (.mk (.vec 2 (.int 32)) (.loc 35)) (.int 64), []⟩ := by
    rw [Valuation.stmt, show (Valuation.entry c s m f).fn = gemv.fn_0 from hf]; rfl
  refine vals_getElem?_eval (nd := .castAt 6 41 0 (.reg 35)) (by decide +kernel) ?_
  rw [SNode.eval_castAt hs, SVal.eval_reg (V := Valuation.entry c s m f) h35]
  exact castV_join (Valuation.entry c s m f).ctx.prog.layout (Valuation.entry c s m f).mem
    (fun i => (Valuation.entry c s m f).ctx.oracle (Nat.pair ((Valuation.entry c s m f).k + 0) i))
    (n := 2) (w := 32) (BitVec.ofNat 64 r)

/-- **The rest of `%6` and `%44` and their edge into the loop, by mojo_obl**, gemv_kernel, for
every valid launch `L`, thread number `k`, context `c` of `gemv`'s program for thread `k` of `L`,
step count `s`, memory `m`, frame `f` of `gemv`'s function, `M, K < 2 ^ 31`, row `r < M` and block
`p0` such that `%0` is the start of `p0`, `%10` and `%11` are the 64-bit words of `M` and `K`,
`%35` is the vector of the halves of `r`'s 64-bit word, and `p0` is a writable buffer of `M`
binary32 aligned to 4 whose generic addresses do not wrap: the premises of `%6` from statement 41
and of `%44` with `fmul contract` hold at `f`'s entry valuation and the path's exit goes to the
header `%54` at position 2 (`EdgeWith true`). The row word is `row_node`'s. -/
theorem entry_edge (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gemv.prog)
    (hce : c.env = L.env k) (s : Nat) (m : Mem) (f : Frame) (hf : f.fn = gemv.fn_0)
    (M K r p0 : Nat) (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hr : r < M)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩))
    (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 M)))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 K)))
    (h35 : f.regs 35 = some (.vec [.bits 32 ((BitVec.ofNat 64 r).extractLsb' 0 32),
      .bits 32 ((BitVec.ofNat 64 r).extractLsb' 32 32)]))
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4)) :
    EdgeWith true loopA.h loopA.p (Valuation.entry c s m f) 6 (gC 6 41).obls (gC 6 41)
      [gB 44 0] := by
  have h36 := row_node c s m f hf r h35
  mojo_obl

/-- The valuation at the header `%54`, position 2, after `%6` from statement 41 and `%44`, from
`V` (`Valuation.roundWith true`, the edge's `phi`s included). A test definition. -/
abbrev head (V : Valuation) : Valuation := Valuation.roundWith true 6 (gC 6 41) [gB 44 0] V

/-- **The header's registers after the edge, by `obl_have`**, gemv_kernel, with the premises of
`entry_edge` but the one on `%10` (the row guard's direction is not needed for the registers): at
the header `%54` after `%6` from statement 41 and `%44`
(`head`), the round `%55` is 0, the sum `%56` is `+0` with no recorded
product, the trip count `%53` is `⌈K / 32⌉ = (K + 31) / 32`, the row's offset `%38` is `r K`, the
lane `%40` is `laneid`, lane 0's flag `%41` is `laneid = 0`, the output pointer `%37` is element
`r` of `p0` (4 bytes each), `%11` is `K`, and the memory is `m`. -/
theorem entry_regs (L : Launch) (hL : L.Valid) (k : Nat) (c : Ctx) (hcp : c.prog = gemv.prog)
    (hce : c.env = L.env k) (s : Nat) (m : Mem) (f : Frame) (hf : f.fn = gemv.fn_0)
    (M K r p0 : Nat) (hM : M < 2 ^ 31) (hK : K < 2 ^ 31) (hr : r < M)
    (hr0 : f.regs 0 = some (.ptr ⟨p0, 0⟩))
    (h11 : f.regs 11 = some (.bits 64 (BitVec.ofNat 64 K)))
    (h35 : f.regs 35 = some (.vec [.bits 32 ((BitVec.ofNat 64 r).extractLsb' 0 32),
      .bits 32 ((BitVec.ofNat 64 r).extractLsb' 32 32)]))
    (hb0 : m.Buffer p0 (M * 4) 4 true) (hf0 : m.Fits gemv.prog.layout p0 (M * 4)) :
    (head (Valuation.entry c s m f)).regs 58 = some (.bits 64 (BitVec.ofNat 64 0)) ∧
      (head (Valuation.entry c s m f)).regs 60 = some (.ofFloat .float (Model.zero _ false)) ∧
      (head (Valuation.entry c s m f)).prods 60 = none ∧
      (head (Valuation.entry c s m f)).regs 54 =
        some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))) ∧
      (head (Valuation.entry c s m f)).regs 38 = some (.bits 64 (BitVec.ofNat 64 (r * K))) ∧
      (head (Valuation.entry c s m f)).regs 40 =
        some (.bits 64 (BitVec.ofNat 64 (L.env k).laneid)) ∧
      (head (Valuation.entry c s m f)).regs 41 = some (.ofBool (decide ((L.env k).laneid = 0))) ∧
      (head (Valuation.entry c s m f)).regs 37 = some (.ptr ⟨p0, ((r * 4 : Nat) : Int)⟩) ∧
      (head (Valuation.entry c s m f)).regs 11 = some (.bits 64 (BitVec.ofNat 64 K)) ∧
      (head (Valuation.entry c s m f)).mem = m := by
  have h36 := row_node c s m f hf r h35
  obl_have g58 : (head (Valuation.entry c s m f)).regs 58,
    g60 : (head (Valuation.entry c s m f)).regs 60, q60 : (head (Valuation.entry c s m f)).prods 60,
    g54 : (head (Valuation.entry c s m f)).regs 54, g38 : (head (Valuation.entry c s m f)).regs 38,
    g40 : (head (Valuation.entry c s m f)).regs 40, g41 : (head (Valuation.entry c s m f)).regs 41,
    g37 : (head (Valuation.entry c s m f)).regs 37, g11 : (head (Valuation.entry c s m f)).regs 11,
    gm : (head (Valuation.entry c s m f)).mem
  refine ⟨g58, g60.trans (by kernel_rfl), q60, g54.trans (OblGevm.word_eq ?_), g38, g40, g41,
    g37.trans (by kernel_rfl), g11, gm⟩
  simp only [Nat.reducePow, Nat.reduceSub, Nat.reduceAdd]
  rw [Nat.max_eq_left (Nat.zero_le _)]
  split <;> omega

/--
info: mojo_obl: open goal
  Exit.dest (Valuation.entry c s m f) (vals (Valuation.entry c s m f) (gC 6 41).nodes)
    (gC 6 41).exit = some 44
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `entry_edge` at `%6`'s branch**: with `r < M` stated as
`MojoProofTest.Obl.Below r M` (irreducible), the row guard `%42 = icmp sge %36, %10` (node 6) need
not be false, so mojo_obl does not find the branch's direction (`%44`, not `%43`) and leaves it
open, as logged; unfolding `Obl.Below` lets it close it,
at every context, step count, memory and frame of `gemv`'s function whose `%10` is `M`'s word and
whose `%35` is the vector of the halves of `r`'s word. -/
theorem entry_open (c : Ctx) (s : Nat) (m : Mem) (f : Frame) (hf : f.fn = gemv.fn_0)
    (M r : Nat) (hM : M < 2 ^ 31) (hr : Obl.Below r M)
    (h10 : f.regs 10 = some (.bits 64 (BitVec.ofNat 64 M)))
    (h35 : f.regs 35 = some (.vec [.bits 32 ((BitVec.ofNat 64 r).extractLsb' 0 32),
      .bits 32 ((BitVec.ofNat 64 r).extractLsb' 32 32)])) :
    Exit.dest (Valuation.entry c s m f) (vals (Valuation.entry c s m f) (gC 6 41).nodes)
      (gC 6 41).exit = some 44 := by
  have h36 := row_node c s m f hf r h35
  mojo_obl
  unfold Obl.Below at hr
  mojo_obl

/-- **A round through `%70`, by mojo_obl**, gemv_kernel: for every `K < 2 ^ 31`, `M` with
`M K < 2 ^ 61`, row `r < M`, lane `l < 32`, round `i < (K + 31) / 32` with `32 i + l < K`, blocks
`bA`, `bV`, row-major matrix `A : M × K` and vector `v` of `K` binary32, accumulator word `acc`
and valuation `W` of `gemv`'s program and function with `%55 = i`, `%53 = (K + 31) / 32`,
`%56 = acc`, `%40 = l`, `%38 = r K`, `%11 = K` (64-bit words), `%1` and `%2` at offset 0 of `bA`
and `bV`, buffers `bA` and `bV` of `M K` and `K` binary32 aligned to 4 whose generic addresses do
not wrap (`Mem.Fits`) and that hold `A` and `v`: the premises of round `i` of `loopA` with
`fmul contract` hold at `W` (`RoundWith true`). -/
theorem roundA (K M r l i bA bV : Nat) (acc : BitVec 32)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K]) (W : Valuation)
    (hK : K < 2 ^ 31) (hMK : M * K < 2 ^ 61) (hr : r < M) (hl : l < 32)
    (hi : i < (K + 31) / 32) (ha : i * 32 + l < K)
    (hP : W.ctx.prog = gemv.prog) (hfn : W.fn = gemv.fn_0)
    (h55 : W.regs 58 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h53 : W.regs 54 = some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))))
    (h56 : W.regs 60 = some (.bits 32 acc))
    (h40 : W.regs 40 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h38 : W.regs 38 = some (.bits 64 (BitVec.ofNat 64 (r * K))))
    (h11 : W.regs 11 = some (.bits 64 (BitVec.ofNat 64 K)))
    (h1 : W.regs 1 = some (.ptr ⟨bA, 0⟩)) (h2 : W.regs 2 = some (.ptr ⟨bV, 0⟩))
    (hbA : W.mem.Buffer bA (M * K * 4) 4 false) (hbV : W.mem.Buffer bV (K * 4) 4 false)
    (hfA : W.mem.Fits gemv.prog.layout bA (M * K * 4))
    (hfV : W.mem.Fits gemv.prog.layout bV (K * 4))
    (hA : W.mem.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A)
    (hV : W.mem.Holds gemv.prog.layout bV (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) v) :
    RoundWith true loopA.h loopA.p loopA.dh loopA.H loopA.B W := by
  mojo_obl

/-- **A round through `%75`, by mojo_obl**, gemv_kernel: for every `K < 2 ^ 31`, `M`, `r`, lane
`l < 32`, round `i < (K + 31) / 32` with `K ≤ 32 i + l`,
blocks `bA`, `bV`, accumulator word `acc` and valuation `W` of `gemv`'s program and function with
`roundA`'s registers and buffers `bA`, `bV` of `M K` and `K` binary32 aligned to 4: the premises
of round `i` of `loopB` hold at `W` (`RoundWith true`). The addresses `%66` and `%68` are past
the buffers (`gep_buffer_ok`) and not loaded. -/
theorem roundB (K M r l i bA bV : Nat) (acc : BitVec 32) (W : Valuation)
    (hK : K < 2 ^ 31) (hl : l < 32)
    (hi : i < (K + 31) / 32) (hb : K ≤ i * 32 + l)
    (hP : W.ctx.prog = gemv.prog) (hfn : W.fn = gemv.fn_0)
    (h55 : W.regs 58 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h53 : W.regs 54 = some (.bits 64 (BitVec.ofNat 64 ((K + 31) / 32))))
    (h56 : W.regs 60 = some (.bits 32 acc))
    (h40 : W.regs 40 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h38 : W.regs 38 = some (.bits 64 (BitVec.ofNat 64 (r * K))))
    (h11 : W.regs 11 = some (.bits 64 (BitVec.ofNat 64 K)))
    (h1 : W.regs 1 = some (.ptr ⟨bA, 0⟩)) (h2 : W.regs 2 = some (.ptr ⟨bV, 0⟩))
    (hbA : W.mem.Buffer bA (M * K * 4) 4 false) (hbV : W.mem.Buffer bV (K * 4) 4 false) :
    RoundWith true loopB.h loopB.p loopB.dh loopB.H loopB.B W := by
  mojo_obl

/-- Position `32 i + l` is below `K`; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def Arm (K i l : Nat) : Prop := i * 32 + l < K

/--
info: mojo_obl: open goal
  Exit.dest (Valuation.intoWith true (Valuation.intoWith true W loopA.h loopA.H) 62 (gC 62 0))
      (vals (Valuation.intoWith true (Valuation.intoWith true W loopA.h loopA.H) 62 (gC 62 0))
        (gC 64 0).nodes)
      (gC 64 0).exit =
    some 74
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `roundA` at `%60`'s branch**: with `32 i + l < K` stated as `Arm`, the guard
`%69 = icmp slt %65, %11` (node 8 of `%60`) need not be true, so mojo_obl does not find the
branch's direction (`%70`) and leaves it open, as logged; unfolding `Arm` lets it close it, for
every `K < 2 ^ 31`, `l`, `i` and valuation whose `%55`, `%40` and `%11` are the words of `i`, `l`
and `K`. -/
theorem arm_open (K l i : Nat) (W : Valuation) (hK : K < 2 ^ 31) (ha : Arm K i l)
    (h55 : W.regs 58 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h40 : W.regs 40 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : W.regs 11 = some (.bits 64 (BitVec.ofNat 64 K))) :
    Exit.dest (Valuation.intoWith true (Valuation.intoWith true W loopA.h loopA.H) 62 (gC 62 0))
      (vals (Valuation.intoWith true (Valuation.intoWith true W loopA.h loopA.H) 62 (gC 62 0))
        (gC 64 0).nodes) (gC 64 0).exit = some 74 := by
  mojo_obl
  unfold Arm at ha
  mojo_obl

/-- Position `32 i + l` is at least `K`; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def Past (K i l : Nat) : Prop := K ≤ i * 32 + l

/--
info: mojo_obl: open goal
  Exit.dest (Valuation.intoWith true (Valuation.intoWith true W loopB.h loopB.H) 62 (gC 62 0))
      (vals (Valuation.intoWith true (Valuation.intoWith true W loopB.h loopB.H) 62 (gC 62 0))
        (gC 64 0).nodes)
      (gC 64 0).exit =
    some 75
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `roundB` at `%60`'s branch**: with `K ≤ 32 i + l` stated as `Past`, the guard
`%69` need not be false, so mojo_obl does not find the branch's direction (`%75`) and leaves it
open, as logged; unfolding `Past` lets it close it, for every `K < 2 ^ 31`, lane `l < 32`, round
`i < (K + 31) / 32` and valuation whose `%55`, `%40` and `%11` are the words of `i`, `l` and
`K`. -/
theorem skip_open (K l i : Nat) (W : Valuation) (hK : K < 2 ^ 31) (hl : l < 32)
    (hi : i < (K + 31) / 32) (hb : Past K i l)
    (h55 : W.regs 58 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h40 : W.regs 40 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h11 : W.regs 11 = some (.bits 64 (BitVec.ofNat 64 K))) :
    Exit.dest (Valuation.intoWith true (Valuation.intoWith true W loopB.h loopB.H) 62 (gC 62 0))
      (vals (Valuation.intoWith true (Valuation.intoWith true W loopB.h loopB.H) 62 (gC 62 0))
        (gC 64 0).nodes) (gC 64 0).exit = some 75 := by
  mojo_obl
  unfold Past at hb
  mojo_obl

/-- `M K` is below `2 ^ 61`; irreducible, so that mojo_obl does not find it. -/
@[irreducible] def MatFits (M K : Nat) : Prop := M * K < 2 ^ 61

/--
info: mojo_obl: open goal
  Cond.Holds
    (Valuation.intoWith true (Valuation.intoWith true (Valuation.intoWith true W loopA.h loopA.H) 62
      (gC 62 0)) 64 (gC 64 0))
    (vals
      (Valuation.intoWith true (Valuation.intoWith true (Valuation.intoWith true W loopA.h loopA.H)
        62 (gC 62 0)) 64 (gC 64 0))
      (gC 74 0).nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `roundA` at the load `%71`**: with `M K < 2 ^ 61` stated as `MatFits`, `2 M K`
need not be below `2 ^ 64`, so `gep_buffer2` does not give the `getelementptr` `%68` (node 7 of
`%60`) as the pointer to element `r K + 32 i + l` of `A` (`gep_buffer_ok` gives some value), and
mojo_obl finds no address for the load `%71` (node 0 of `%70`) and leaves its obligation open,
as logged; unfolding `MatFits` lets it close it. -/
theorem matrix_open (K M r l i bA : Nat) (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (W : Valuation) (hMK : MatFits M K) (hr : r < M) (ha : i * 32 + l < K)
    (hP : W.ctx.prog = gemv.prog) (hfn : W.fn = gemv.fn_0)
    (h55 : W.regs 58 = some (.bits 64 (BitVec.ofNat 64 i)))
    (h40 : W.regs 40 = some (.bits 64 (BitVec.ofNat 64 l)))
    (h38 : W.regs 38 = some (.bits 64 (BitVec.ofNat 64 (r * K))))
    (h1 : W.regs 1 = some (.ptr ⟨bA, 0⟩)) (hbA : W.mem.Buffer bA (M * K * 4) 4 false)
    (hfA : W.mem.Fits gemv.prog.layout bA (M * K * 4))
    (hA : W.mem.Holds gemv.prog.layout bA (.fp .float) (Val.ofFloat .float)
      (rowMajor gemv.prog.layout (.fp .float) 0) A) :
    Cond.Holds
      (Valuation.intoWith true (Valuation.intoWith true (Valuation.intoWith true W loopA.h
        loopA.H) 62 (gC 62 0)) 64 (gC 64 0))
      (vals (Valuation.intoWith true (Valuation.intoWith true (Valuation.intoWith true W loopA.h
        loopA.H) 62 (gC 62 0)) 64 (gC 64 0)) (gC 74 0).nodes) (.ok (.node 0)) := by
  mojo_obl
  unfold MatFits at hMK
  mojo_obl

end MojoProofTest.OblGemv
