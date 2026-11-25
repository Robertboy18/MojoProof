---
id: naive-matmul
title: matmul_kernel_naive, one thread per output cell of C = A B (TorchLean.Tensor.matmul)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/linalg/matmul/gpu/__init__.mojo:253
quote: "def matmul_kernel_naive["
lean: TorchLean.Tensor.matmul, MojoProof.Sem.matmul_cell_real
corpus: tests/corpus/mgemm/g_matmul_kernel_naive_*, tests/corpus/mgemm_nocontract, tests/corpus/mgemm_sm80
tests: MojoProofTest.Matmul, MojoProofTest.SymNaive, MojoProofTest.SymContract, MojoProofTest.SymPhi, MojoProofTest.NaiveThread, MojoProofTest.NaiveStart, MojoProofTest.NaiveKernel, MojoProofTest.NaiveOff, MojoProofTest.ContractOff, MojoProofTest.Gpu, MojoProofTest.Family, MojoProofTest.NaiveFamRun
upstream:
depends: launch, contract, binary-op-rounding
level: L4
evidence: L1: tests/gpu/naive/record.txt; L2: MojoProofTest.NaiveKernel.correct, MojoProofTest.NaiveOff.correct; L3: MojoProofTest.NaiveKernel.matmul_nanEq, MojoProofTest.NaiveOff.matmul_nanEq; L4: MojoProofTest.NaiveKernel.matmul_error, MojoProofTest.NaiveOff.matmul_error
---

# The naive matmul

**The rule.** The thread at output cell `(i, j)` inside the `m × n` result accumulates
`A[i, l] * B[l, j]` for `l` below `k`, in order, and writes the sum to `C[i, j]`.

**What is in the code.** The corpus has 13 specializations from the multistage GEMM test (10
float32, one bfloat16, one mixed float32/bfloat16, one float8 input), the 10 float32 ones
built with contraction off (tests/corpus/mgemm_nocontract) and the GPU run's float32 one built
for sm_80 (tests/corpus/mgemm_sm80). All import but the float8 one,
refused at an inline asm conversion (tests/corpus/REFUSALS.tsv). The block checker with
`fmul contract` recorded accepts all nine of the naive kernel's blocks, the preheader's float
constant `0.0` among them as a node of its table (MojoProofTest.SymNaive,
MojoProofTest.SymContract, MojoProofTest.SymPhi), and two rounds of its loop run at one thread
(MojoProofTest.SymNaive). `MojoProof.Sem.matmul_cell_real` is the cell's value over the
reals for the evaluator's dot loop, a statement about the loop, not about the kernel.

**One thread, for one float32 specialization.** `MojoProofTest.NaiveThread.thread_run` runs an
in-bounds thread from the kernel's entry through the loop to `ret`, for every thread of every
launch, every trip count and every predicate on the memory at the return, from premises: the
obligations the checker does not decide (the bound `%47 < smax(K, 0)`, the address arithmetic of
the loads and the store, the in-bounds test), each round's register updates and the path out.
The oracle numbers of round `j`'s `fmul` and `fadd`, steps `54 + 18 j` and `55 + 18 j` from the
thread's start, are proved from the step count. `MojoProofTest.NaiveThread.thread0` discharges
the premises at one launch (one block of 2 × 2 threads, `m = n = 1`, `K = 2`, one memory, one
oracle), for its one thread in bounds: from `Grid.start`'s frame to its end, cell `(0, 0)`
holds the contracted dot loop at those oracle numbers; `thread0_twin` shows the positions one
step later give another word. `MojoProofTest.NaiveThread.thread_skip` runs an out-of-bounds
thread through `%6 → %44 → %69` to `ret`, for every thread and every predicate on the memory at
the return, from the entry block's obligations and branch; it stores nothing. `skip_threads`
runs the launch's other three threads by it, so every thread of that launch runs to its end.
`MojoProofTest.NaiveIn.runIn` is `MojoProofTest.NaiveSound.naive.runInv` at a symbolic thread: for
every launch, size, buffer, oracle family and pair of matrices, every in-bounds thread whose entry
facts are `NaiveSpec.At` runs to `ret` and its store puts the contracted dot loop of its row and
column at its cell (`NaiveSpec.RunIn`). `MojoProofTest.NaiveOut.runOut` does the same for every
out-of-bounds thread, which skips to `ret` and stores nothing (`NaiveSpec.RunOut`); it is
`MojoProofTest.NaiveSound.naive.out`, the run of an out-of-bounds thread that `mojo_kernel`'s `mat`
clause generates, at `At`'s facts; its instance is `runsZ`, a launch with `m = n = 0`.
`MojoProofTest.NaiveStart.runs12` is an instance of both at an evaluated start (one block of 2 × 2
threads, `m = 1`, `n = 2`, every `A`, `B`, `K ≤ 768` and oracle): `runIn` at threads 0 and 2,
`runOut` at threads 1 and 3. `thread0` and `skip_threads` are not their instances, since that
launch's blocks are smaller than `At` asks for.

**The kernel theorem, for one float32 specialization.** `MojoProofTest.NaiveKernel.correct` is
`Kernel.Sound` of the kernel compiled with `fmul contract`, for every oracle family, valid launch
with side 1 in `z`, sizes, blocks, tensors and memory meeting the matmul precondition `Mat.Pre`
(`MojoProof.Sem.Mat.Pre`): the launch starts, no run faults or races, every run terminates, and
every final memory holds the contracted dot loop of row `r` of `A` and row `c` of `B` over the
first `K` columns at each cell `(r, c)` with `r < m`, `c < n` and inside the launch's window
(`r < grid.x * block.x`, `c < grid.y * block.y`), every other byte the caller's. It is the
family's theorem `MojoProofTest.NaiveFam.sound` at the corpus strides 768, 768 and 50257 (below,
"The kernel theorem at every row stride"). The `mat … inv` clause of `mojo_kernel` proves the
same theorem for this one program: the library's kernel theorem of a matmul kernel from its
threads' runs, `MojoProof.Sym.Kernel.sound_mat`, at the naive kernel
(`MojoProofTest.NaiveSound.naive_sound`, from the run of an in-bounds thread only), through
`MojoProofTest.NaiveSound.naive.sound_mat`, the call that `mojo_kernel`'s `mat` clause generates
with the run of an out-of-bounds thread (`MojoProofTest.NaiveSound.naive.out`). The run of an
in-bounds thread is `MojoProofTest.NaiveSound.naive.runInv`, which the `mat … inv` clause
generates from an invariant of the loop at the heads of its rounds
(`MojoProof.Sym.LoopIterWith`) by `MojoProof.Sym.RetLsWith.of_iter`, and it proves the function,
the buffers, `Elem` and `Elem.Only` at every head itself (`MojoProof.Sym.Mat.Head`, by
`MojoProof.Sym.Mat.Head.iterate`) and the registers the loop keeps
(`MojoProofTest.NaiveSound.naive.kept`, by `MojoProof.Sym.LoopSeg.kept_round`); the invariant
(`MojoProofTest.NaiveThread.Inv` with `%48`'s `fmul contract` operands) and its three facts are
proved by hand: at the loop head (`MojoProofTest.NaiveIn.head_in`), at each round
(`MojoProofTest.NaiveIn.round_in` and `MojoProofTest.NaiveThread.round_inv`) and at the exit
(`MojoProofTest.NaiveIn.exit_in`).
`MojoProofTest.NaiveKernel.sound12` is its instance at one block of 2 × 2 threads, two of them in
bounds, with `K = 768`, at the start that `MojoProofTest.NaiveStart.start12` evaluates; at every
address choice and oracle that start has a complete run whose blocks meet `Elem.Out`
(`MojoProofTest.NaiveStart.obs12`), so the cells `MojoProofTest.NaiveKernel.read12` reads are
those of a run that exists (`MojoProofTest.NaiveStart.cells12`).
`MojoProofTest.NaiveKernel.read_cover` reads every cell of `C` off when the
window covers `m × n` (`m ≤ grid.x * block.x`, `n ≤ grid.y * block.y`); a cell outside the window
keeps the caller's bytes: `MojoProofTest.NaiveKernel.keep11`, a launch of one thread with
`m = 1`, `n = 2`, writes only `C[0, 0]`.

**The kernel theorem at every row stride.** `MojoProofTest.NaiveFam.prog sA sB sC` is the
float32 kernel compiled with `fmul contract` with the constants of its three stride
multiplications as parameters (the command `mojo_family`, MojoProofTest.Family): the corpus file
16826c8c is its value at 768, 768 and 50257 (`MojoProofTest.NaiveFam.prog_corpus`), and
tests/corpus/naive_k512 its value at 512, 512 and 256 up to the kernel's name.
`MojoProofTest.NaiveFam.sound` is `Kernel.Sound` of it for every row stride `sA`, `sB`, `sC`,
oracle family, valid launch with side 1 in `z`, sizes `m`, `n`, `K` below `2 ^ 31`, blocks,
tensors and memory meeting `Mat.Pre` at those strides (so `n ≤ sC` and `K ≤ min sA sB`), for
`Elem.Out` of the family's bytes at the cells `MojoProofTest.NaiveFam.cell`. Its run of an
in-bounds thread is `MojoProofTest.NaiveFam.runInF`, with the entry block summarized as a
function of the strides (`MojoProofTest.NaiveFam.entryF`, by the command `sym_summary_family`)
and the invariant's three facts proved by hand at every stride (`MojoProofTest.NaiveFam.head_inF`,
`MojoProofTest.NaiveFam.round_inF`, `MojoProofTest.NaiveFam.exit_inF`); an out-of-bounds thread
is `MojoProofTest.NaiveFam.outF`. `MojoProofTest.NaiveKernel.correct` and
`MojoProofTest.NaiveFam.sound_512_512_256` are its instances at the two specializations, one line
each. With contraction off, `MojoProofTest.NaiveOff.soundF`, `MojoProofTest.NaiveOff.matmul_nanEqF`
and `MojoProofTest.NaiveOff.matmul_errorF` hold at every row stride and `K ≤ min sA sB`, and
`MojoProofTest.NaiveOff.correct`, `matmul_nanEq` and `matmul_error` are their instances at the
corpus file (`MojoProofTest.NaiveOff.corpus_off`). The other nine float32 files of
tests/corpus/mgemm are not yet checked to be members of the family.

**The kernel compiled with contraction off.** `MojoProofTest.NaiveOff.correct` is
`Kernel.Sound` of the float32 kernel of tests/corpus/mgemm_nocontract, at every oracle family
`ω`, valid launch with side 1 in `z`, sizes, blocks, tensors and memory meeting `Mat.Pre`, for
`Elem.Out` of the naive kernel's bytes at the never-fusing rows `neverFuse (ω k)`. It is
`NaiveKernel.correct` at those rows, moved by `MojoProof.Sem.Kernel.Sound.contractOff`.
`MojoProofTest.NaiveOff.correct_unfused` states the same bytes as the unfused dot loop
(`MojoProof.Sem.dotLoop` with no fusion: the float32 product rounded, then the sum rounded), by
`MojoProofTest.NaiveOff.bytes_neverFuse` and `MojoProof.Sem.dotLoop_neverFuse`. Every final
memory holds it at each cell in bounds and inside the launch's window, and every other byte is
the caller's. `Kernel.Sound.contractOff` holds for every program whose only oracle readers are
float binary operations, a premise the naive kernel meets by evaluation. Its converse at the
never-fusing rows is `MojoProof.Sem.Kernel.Sound.contractOff_iff`. By evaluation, the program's
module is the naive kernel's with the `contract` flags removed.
`MojoProofTest.NaiveOff.matmul_nanEq` and `MojoProofTest.NaiveOff.matmul_error` compare it with
TorchLean for every `K ≤ 768`: each cell in bounds and in the launch's window is `NaNEq` to
`Tensor.matmul` of the first `K` columns, with no premise on the oracle, and within `dotBound` of
the real product when finite. A run under any oracle family is a run of the naive kernel under the
never-fusing one (`MojoProof.Sym.Kernel.Obs.contractOff`, for every program of the fragment
`Program.fbinOracle`; both directions in `MojoProof.Sym.Kernel.Obs.contractOff_iff`), and the two
comparisons are `MojoProofTest.NaiveKernel.matmul_nanEq` and `matmul_error` at that run. These
cover one program, every launch valid with side 1 in `z` (the cells in its window) and every
memory of `Mat.Pre`.

**Against TorchLean, for one float32 specialization.** For every oracle family, valid launch with
side 1 in `z`, `K ≤ 768`, sizes, blocks, tensors and memory meeting `Mat.Pre`, every complete
run's cell `(r, c)` in bounds and in the window holds a binary32 word `v`.
`MojoProofTest.NaiveKernel.matmul_nanEq` (L3): `v` and entry `(r, c)` of
`TorchLean.Tensor.matmul` of the first `K` columns of `A` and of `B` transposed are the same word
or both NaNs, at a thread whose oracle fuses no round (none of its `fadd contract` rounds the
product and the sum once). The equality needs that premise, which the scope column does not show;
`MojoProofTest.NaiveKernel.nanEq_zero` is its instance at an oracle family that fuses nothing.
`MojoProofTest.NaiveKernel.matmul_error` (L4): when `v` is finite, it is within `dotBound` of
binary32 at `K` of the real product, for every oracle family, so for every choice of fused
rounds.

**A GPU run (L1).** tests/gpu/naive/record.txt records a run of the float32 specialization on
an A100 (sm_80): a driver of the multistage GEMM test's launch of it (tests/gpu/naive/), whose
IR for sm_80 is tests/corpus/mgemm_sm80/. That file differs from the proved one
(tests/corpus/mgemm/, suffix `16826c8c`) in the kernel's name and the target attributes only:
`MojoProofTest.Gpu.naiveSm80_fn` shows that its imported function is the proved program's but
for its name, and `MojoProofTest.Gpu.naiveSm80_prog` that its program differs only in the name,
the file's digest, the kernel list and attribute group 0. On 8 launches (threads out of bounds
in `x` and in `y`, `m` and `n` not multiples of 16, `K` of 0, 1, 2, 7, 33 and 768), the
evaluator on that import, every thread with the oracle that fuses each round (always 2), gives
the GPU's whole `C` bit for bit: the 1356 cells and the 2762779 other words, which keep their
sentinel. A conformance test of the compiled kernel on these inputs, not a proof: no theorem says
that the evaluator's runs of the two imports agree.

**Not proved.** The kernel theorem covers one of the 13 specializations, and its contraction-off
build. For the build with contraction, the L3 equality is proved only at a thread whose oracle
fuses no round; at a fused round only L4's bound holds. The start of a launch of `At`'s sizes
evaluates in the kernel with its check of the caller's memory in place
(`MojoProofTest.NaiveStart.start12`); `correct` is applied at that start for `K = 768` only
(`MojoProofTest.NaiveKernel.sound12`), and at no other launch or memory.

**Open.** The other specializations; generating or discharging the invariant's three facts (at
the loop head, at each round and at the exit), which are proved by hand. The `mat … inv` clause
generates the run of an in-bounds thread from them (`MojoProofTest.NaiveSound.naive.runInv`),
with the facts `MojoProof.Sym.Mat.Head` and the registers the loop keeps
(`MojoProofTest.NaiveSound.naive.kept`) at every head of a round, and the run of an
out-of-bounds thread (`MojoProofTest.NaiveSound.naive.out`).
