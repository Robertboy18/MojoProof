import MojoProofTest.LnRun

/-!
# Layer norm's last loop at block sizes 64, 256 and 1024: the premises at the corpus files

Tests of MojoProofTest/LnRun.lean's run theorems for every block size (`run_entryB`) at the block
sizes of the three other corpus files of layer norm's family, with the premises evaluated at those
files: ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, ..._bs256_762bdc07.nvptx.ll and
..._bs1024_c4d21970.nvptx.ll in tests/corpus/layernorm/, by `mojo_import` as `ln64`, `ln256` and
`ln1024`. Each has 828 lines, the bs128 file's (MojoProofTest/SymSeg.lean's `ln`) but for the block
size `B` at :6 (the shared array's size), :30 (`icmp slt i64 %21, B/32`), :117
(`%79 = add i64 %73, B`), :681 (the loop's step `%473 = add i64 %471, B`) and :817, and the kernel's
and the shared array's names. For each `B` of 64, 256 and 1024 (the theorems named with the block
size, `hdr_64`, `hdr_256`, `hdr_1024` and so on):

* `hdr_64`, `hdr_256`, `hdr_1024`: the file's header `%469` from statement 3 (:677-690) summarizes
  (`summarize`, at the file's program and function) to `hdrB B`, the family's header at `B`.
* `file_64`, `file_256`, `file_1024`: the path checker (`coversPathAt`, `phi`s and `fmul contract`,
  no `alloca`) accepts, at the file's program and function, the family's rounds `lnTB B` and
  `lnFB B`, the path out of the loop and the edge into it, as `LnCovers B` does at `lnFam.fn B`:
  each block of those paths in the file (:675-774) summarizes to the family's summary at `B`.
* `covers_64`, `covers_256`, `covers_1024`: `LnCovers B`, the premise of the run theorems, by the
  checker at `B`.
* `run_entry_64`, `run_entry_256`, `run_entry_1024`: `run_entryB` at `B`, for every context of
  `ln.prog` (so every launch and thread), thread `tid < 1024`, row length `n < 2 ^ 32`, memory and
  rows with its premises: the thread's final loop stores at the floats of `lnStores B n tid`.
* `stores_64`, `stores_256`, `stores_1024`: `lnStores B n tid` evaluated, at `n = 300` (3000 at
  `B = 1024`) and threads 43 and 44.

And `layouts`: the three files' programs have `ln.prog`'s layout. The mutant `hdr_256_ne`: the bs256
file's header does not summarize to the bs128 file's `hdr`, and the checker rejects the bs128 round
`lnT` at the bs256 file.

The premises on `B` of the run theorems: `0 < B` (the fuel: the loop leaves after at most `n`
rounds, `n ≤ B n`), `B ≤ 2 ^ 32` (the step `%473` and the index `%485` do not overflow: `i + B` and
`i + tid` stay below `2 ^ 63` for `i < n + B`, `n < 2 ^ 32`) and `LnCovers B` (the checker at `B`).
Each holds at 64, 128, 256 and 1024 (`covers_128` in LnRun.lean).

What is still given: the run theorems are about the family's function `lnFam.fn B` in a context of
the bs128 file's program `ln.prog`, not about each file's own function in its own program (the bs256
file's are ln256.fn_0 and ln256.prog, say). In the loop the two functions have the same summaries,
block by block (`file_64`, `file_256`, `file_1024`), and the programs the same layout (`layouts`),
but the step from `lnFam.fn B` in `ln.prog` to the file's function in the file's program (that a
round's premises and its run depend on the function only through the blocks at the loop's labels and
on the program only through its layout) is not proved (docs/proofs/layernorm.md's plan). The mean
`%460` and inverse deviation `%464` are given registers; it is one thread's final loop, not the
launch.
-/

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymSeg
open MojoProofTest.LnRound MojoProofTest.LnRun
open FloatLib.Floats.Formats.BinaryInterchange
open MojoProofTest.GPUProof.ViewStride (lnStores)

namespace MojoProofTest.LnFamily

-- Layer norm at block size 64: ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll.
mojo_import "layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll" as ln64

-- Layer norm at block size 256: ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll.
mojo_import "layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll" as ln256

-- Layer norm at block size 1024: ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll.
mojo_import "layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll" as ln1024

/-- The bs64 file's header `%469` from statement 3 (IR :677-690 of
ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll) summarizes to `hdrB 64`, the family's header
at block size 64 (the step `%473 = add i64 %471, 64`, :681). By `decide +kernel`. A fact about one
kernel file's words. -/
theorem hdr_64 : summarize ln64.prog ln64.fn_0 ln.fn_0.b_43.label 3 = some (hdrB 64) := by
  decide +kernel

/-- The path checker with `phi`s and `fmul contract` (`coversPathAt`, no `alloca`) accepts, at the
bs64 file's program and function (ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, IR
:675-774), the family's rounds at block size 64, `lnTB 64` and `lnFB 64`, the path out of the loop
from the header's statement 3, and the edge into the loop from `%453`'s branch (statement 21): the
file's blocks of the loop summarize to the family's at 64. By `decide +kernel`. A fact about one
kernel file's words. -/
theorem file_64 :
    coversPathAt false true ln64.prog ln64.fn_0 3
      (((lnTB 64).h, (lnTB 64).dh, (lnTB 64).H) :: (lnTB 64).B) = true ∧
    coversPathAt false true ln64.prog ln64.fn_0 3
      (((lnFB 64).h, (lnFB 64).dh, (lnFB 64).H) :: (lnFB 64).B) = true ∧
    coversPathAt false true ln64.prog ln64.fn_0 3
      (((lnFB 64).h, (lnFB 64).dh, (lnFB 64).H) :: (lnFB 64).X) = true ∧
    coversPathAt false true ln64.prog ln64.fn_0 21
      [(ln.fn_0.b_42.label, pre.obls, pre)] = true := by
  decide +kernel

/-- The covers of layer norm's last loop at block size 64 (`LnCovers 64`, at the family's
function `lnFam.fn 64` in `ln.prog`), the premise of the run theorems at 64. By
`decide +kernel`. -/
theorem covers_64 : LnCovers 64 :=
  ⟨by decide +kernel, by decide +kernel, by decide +kernel, by decide +kernel⟩

/-- **Layer norm's last loop from its entry at block size 64.** `run_entryB` at `B = 64` (the block
size of ln_rowwise_block_t0_r1_ax0_w1_bs64_f6f88241.nvptx.ll, IR :675-774), for the family's
function `lnFam.fn 64`, every context `c` of `ln.prog` (so every launch and thread), thread index
`tid < 1024`, row length `n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`,
`mu`, `rs`, thread state `t` whose innermost frame `f` is at `%453`'s branch into the loop and
memory `m`, with `run_entryB`'s registers and memory: the thread's steps reach `%534`'s first
statement, and its trace and blocks are `m`'s with the rounds at the floats of `lnStores 64 n tid`
(`LnTrace`, `LnOut` at `LnBytes`). A run theorem at one block size; its premises on `B` by
`covers_64` and evaluation; the mean and inverse deviation are given registers. -/
theorem run_entry_64 {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32)
    (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) {t : Thread}
    {m : Mem} {f : Frame} {rest : List Frame} (hfr : t.frames = f :: rest)
    (hf : f.fn = lnFam.fn 64) (hl : f.label = ln.fn_0.b_42.label) (hp : f.pc = 21)
    (h24 : f.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (h67 : f.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : f.regs 462 = some (.ofFloat .float mu))
    (h466 : f.regs 466 = some (.ofFloat .float rs))
    (hq462 : f.prods 462 = none) (hq466 : f.prods 466 = none)
    (h468 : f.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : f.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : f.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : f.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby' : m.Buffer y (n * 4) 4 true) (hbg : m.Buffer g (n * 4) 4 false)
    (hbb : m.Buffer b (n * 4) 4 false) (hbx : m.Buffer x (n * 4) 4 false)
    (hfy : m.Fits ln.prog.layout y (n * 4)) (hfg : m.Fits ln.prog.layout g (n * 4))
    (hfb : m.Fits ln.prog.layout b (n * 4)) (hfx : m.Fits ln.prog.layout x (n * 4))
    (hX : m.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : m.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : m.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = lnFam.fn 64 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) (lnStores 64 n tid) m m' ∧
      LnTrace c.who y g b x (lnStores 64 n tid) m m' :=
  run_entryB hc covers_64 (by decide) ht hn (by decide) hxy hgy hby hfr hf hl hp h24 h67 h462 h466
    hq462 hq466 h468 h469 h470 h72 hby' hbg hbb hbx hfy hfg hfb hfx hX hG hB

/-- The floats of the rounds at block size 64 (`run_entry_64`'s `lnStores 64 n tid`), at row
length `n = 300`: thread 43 stores floats 43, 107, 171, 235, 299, thread 44 floats
44, 108, 172, 236. By evaluation. A test of one size. -/
theorem stores_64 :
    lnStores 64 300 43 = [43, 107, 171, 235, 299] ∧ lnStores 64 300 44 = [44, 108, 172, 236] := by
  decide

/-- The bs256 file's header `%469` from statement 3 (IR :677-690 of
ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll) summarizes to `hdrB 256`, the family's header
at block size 256 (the step `%473 = add i64 %471, 256`, :681). By `decide +kernel`. A fact about one
kernel file's words. -/
theorem hdr_256 : summarize ln256.prog ln256.fn_0 ln.fn_0.b_43.label 3 = some (hdrB 256) := by
  decide +kernel

/-- The path checker with `phi`s and `fmul contract` (`coversPathAt`, no `alloca`) accepts, at the
bs256 file's program and function (ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, IR
:675-774), the family's rounds at block size 256, `lnTB 256` and `lnFB 256`, the path out of the
loop from the header's statement 3, and the edge into the loop from `%453`'s branch (statement 21):
the file's blocks of the loop summarize to the family's at 256. By `decide +kernel`. A fact about
one kernel file's words. -/
theorem file_256 :
    coversPathAt false true ln256.prog ln256.fn_0 3
      (((lnTB 256).h, (lnTB 256).dh, (lnTB 256).H) :: (lnTB 256).B) = true ∧
    coversPathAt false true ln256.prog ln256.fn_0 3
      (((lnFB 256).h, (lnFB 256).dh, (lnFB 256).H) :: (lnFB 256).B) = true ∧
    coversPathAt false true ln256.prog ln256.fn_0 3
      (((lnFB 256).h, (lnFB 256).dh, (lnFB 256).H) :: (lnFB 256).X) = true ∧
    coversPathAt false true ln256.prog ln256.fn_0 21
      [(ln.fn_0.b_42.label, pre.obls, pre)] = true := by
  decide +kernel

/-- The covers of layer norm's last loop at block size 256 (`LnCovers 256`, at the family's
function `lnFam.fn 256` in `ln.prog`), the premise of the run theorems at 256. By
`decide +kernel`. -/
theorem covers_256 : LnCovers 256 :=
  ⟨by decide +kernel, by decide +kernel, by decide +kernel, by decide +kernel⟩

/-- **Layer norm's last loop from its entry at block size 256.** `run_entryB` at `B = 256` (the
block size of ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll, IR :675-774), for the family's
function `lnFam.fn 256`, every context `c` of `ln.prog` (so every launch and thread), thread index
`tid < 1024`, row length `n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`,
`mu`, `rs`, thread state `t` whose innermost frame `f` is at `%453`'s branch into the loop and
memory `m`, with `run_entryB`'s registers and memory: the thread's steps reach `%534`'s first
statement, and its trace and blocks are `m`'s with the rounds at the floats of `lnStores 256 n tid`
(`LnTrace`, `LnOut` at `LnBytes`). A run theorem at one block size; its premises on `B` by
`covers_256` and evaluation; the mean and inverse deviation are given registers. -/
theorem run_entry_256 {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32)
    (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) {t : Thread}
    {m : Mem} {f : Frame} {rest : List Frame} (hfr : t.frames = f :: rest)
    (hf : f.fn = lnFam.fn 256) (hl : f.label = ln.fn_0.b_42.label) (hp : f.pc = 21)
    (h24 : f.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (h67 : f.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : f.regs 462 = some (.ofFloat .float mu))
    (h466 : f.regs 466 = some (.ofFloat .float rs))
    (hq462 : f.prods 462 = none) (hq466 : f.prods 466 = none)
    (h468 : f.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : f.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : f.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : f.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby' : m.Buffer y (n * 4) 4 true) (hbg : m.Buffer g (n * 4) 4 false)
    (hbb : m.Buffer b (n * 4) 4 false) (hbx : m.Buffer x (n * 4) 4 false)
    (hfy : m.Fits ln.prog.layout y (n * 4)) (hfg : m.Fits ln.prog.layout g (n * 4))
    (hfb : m.Fits ln.prog.layout b (n * 4)) (hfx : m.Fits ln.prog.layout x (n * 4))
    (hX : m.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : m.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : m.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = lnFam.fn 256 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) (lnStores 256 n tid) m m' ∧
      LnTrace c.who y g b x (lnStores 256 n tid) m m' :=
  run_entryB hc covers_256 (by decide) ht hn (by decide) hxy hgy hby hfr hf hl hp h24 h67 h462 h466
    hq462 hq466 h468 h469 h470 h72 hby' hbg hbb hbx hfy hfg hfb hfx hX hG hB

/-- The floats of the rounds at block size 256 (`run_entry_256`'s `lnStores 256 n tid`), at row
length `n = 300`: thread 43 stores floats 43, 299, thread 44 floats
44. By evaluation. A test of one size. -/
theorem stores_256 :
    lnStores 256 300 43 = [43, 299] ∧ lnStores 256 300 44 = [44] := by
  decide

/-- The bs1024 file's header `%469` from statement 3 (IR :677-690 of
ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll) summarizes to `hdrB 1024`, the family's
header at block size 1024 (the step `%473 = add i64 %471, 1024`, :681). By `decide +kernel`. A fact
about one kernel file's words. -/
theorem hdr_1024 : summarize ln1024.prog ln1024.fn_0 ln.fn_0.b_43.label 3 = some (hdrB 1024) := by
  decide +kernel

/-- The path checker with `phi`s and `fmul contract` (`coversPathAt`, no `alloca`) accepts, at the
bs1024 file's program and function (ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, IR
:675-774), the family's rounds at block size 1024, `lnTB 1024` and `lnFB 1024`, the path out of the
loop from the header's statement 3, and the edge into the loop from `%453`'s branch (statement 21):
the file's blocks of the loop summarize to the family's at 1024. By `decide +kernel`. A fact about
one kernel file's words. -/
theorem file_1024 :
    coversPathAt false true ln1024.prog ln1024.fn_0 3
      (((lnTB 1024).h, (lnTB 1024).dh, (lnTB 1024).H) :: (lnTB 1024).B) = true ∧
    coversPathAt false true ln1024.prog ln1024.fn_0 3
      (((lnFB 1024).h, (lnFB 1024).dh, (lnFB 1024).H) :: (lnFB 1024).B) = true ∧
    coversPathAt false true ln1024.prog ln1024.fn_0 3
      (((lnFB 1024).h, (lnFB 1024).dh, (lnFB 1024).H) :: (lnFB 1024).X) = true ∧
    coversPathAt false true ln1024.prog ln1024.fn_0 21
      [(ln.fn_0.b_42.label, pre.obls, pre)] = true := by
  decide +kernel

/-- The covers of layer norm's last loop at block size 1024 (`LnCovers 1024`, at the family's
function `lnFam.fn 1024` in `ln.prog`), the premise of the run theorems at 1024. By
`decide +kernel`. -/
theorem covers_1024 : LnCovers 1024 :=
  ⟨by decide +kernel, by decide +kernel, by decide +kernel, by decide +kernel⟩

/-- **Layer norm's last loop from its entry at block size 1024.** `run_entryB` at `B = 1024` (the
block size of ln_rowwise_block_t0_r1_ax0_w1_bs1024_c4d21970.nvptx.ll, IR :675-774), for the family's
function `lnFam.fn 1024`, every context `c` of `ln.prog` (so every launch and thread), thread index
`tid < 1024`, row length `n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`,
`mu`, `rs`, thread state `t` whose innermost frame `f` is at `%453`'s branch into the loop and
memory `m`, with `run_entryB`'s registers and memory: the thread's steps reach `%534`'s first
statement, and its trace and blocks are `m`'s with the rounds at the floats of `lnStores 1024 n tid`
(`LnTrace`, `LnOut` at `LnBytes`). A run theorem at one block size; its premises on `B` by
`covers_1024` and evaluation; the mean and inverse deviation are given registers. -/
theorem run_entry_1024 {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32)
    (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) {t : Thread}
    {m : Mem} {f : Frame} {rest : List Frame} (hfr : t.frames = f :: rest)
    (hf : f.fn = lnFam.fn 1024) (hl : f.label = ln.fn_0.b_42.label) (hp : f.pc = 21)
    (h24 : f.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (h67 : f.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : f.regs 462 = some (.ofFloat .float mu))
    (h466 : f.regs 466 = some (.ofFloat .float rs))
    (hq462 : f.prods 462 = none) (hq466 : f.prods 466 = none)
    (h468 : f.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : f.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : f.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : f.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby' : m.Buffer y (n * 4) 4 true) (hbg : m.Buffer g (n * 4) 4 false)
    (hbb : m.Buffer b (n * 4) 4 false) (hbx : m.Buffer x (n * 4) 4 false)
    (hfy : m.Fits ln.prog.layout y (n * 4)) (hfg : m.Fits ln.prog.layout g (n * 4))
    (hfb : m.Fits ln.prog.layout b (n * 4)) (hfx : m.Fits ln.prog.layout x (n * 4))
    (hX : m.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : m.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : m.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = lnFam.fn 1024 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) (lnStores 1024 n tid) m m' ∧
      LnTrace c.who y g b x (lnStores 1024 n tid) m m' :=
  run_entryB hc covers_1024 (by decide) ht hn (by decide) hxy hgy hby hfr hf hl hp h24 h67 h462 h466
    hq462 hq466 h468 h469 h470 h72 hby' hbg hbb hbx hfy hfg hfb hfx hX hG hB

/-- The floats of the rounds at block size 1024 (`run_entry_1024`'s `lnStores 1024 n tid`), at row
length `n = 3000`: thread 43 stores floats 43, 1067, 2091, thread 44 floats
44, 1068, 2092. By evaluation. A test of one size. -/
theorem stores_1024 :
    lnStores 1024 3000 43 = [43, 1067, 2091] ∧ lnStores 1024 3000 44 = [44, 1068, 2092] := by
  decide

/-- The three files' programs have the bs128 file's layout (the sizes, alignments and encodings
of `ln.prog`'s types, which the run theorems' premises `Mem.Fits` and `Mem.Holds` read): the
files ln_rowwise_block_t0_r1_ax0_w1_bs{64,256,1024}. By `rfl`. A fact about the kernel files'
words. -/
theorem layouts : ln64.prog.layout = ln.prog.layout ∧ ln256.prog.layout = ln.prog.layout ∧
    ln1024.prog.layout = ln.prog.layout :=
  ⟨rfl, rfl, rfl⟩

/-- The mutant: the bs256 file's header (ln_rowwise_block_t0_r1_ax0_w1_bs256_762bdc07.nvptx.ll,
:677-690) does not summarize to the bs128 file's `hdr` (its step is `%473 = add i64 %471, 256`),
and the path checker rejects the bs128 round `lnT` at the bs256 file's program and function. By
`decide +kernel`. A fact about one kernel file's words. -/
theorem hdr_256_ne : summarize ln256.prog ln256.fn_0 ln.fn_0.b_43.label 3 ≠ some hdr ∧
    coversPathAt false true ln256.prog ln256.fn_0 3 ((lnT.h, lnT.dh, lnT.H) :: lnT.B) = false := by
  decide +kernel

end MojoProofTest.LnFamily
