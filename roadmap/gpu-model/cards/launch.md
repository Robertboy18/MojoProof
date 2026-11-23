---
id: launch
title: threads and the launch, the grid and blocks of threads and their special registers
kind: construct
ref: PTX ISA 9.5 #special-registers
quote: ""
lean: MojoProof.Sem.Launch, MojoProof.Sem.Launch.Valid, MojoProof.Sem.Launch.env, MojoProof.Sem.Env.sreg, MojoProof.Sem.Env.laneid, MojoProof.LLVM.SReg, MojoProof.LLVM.Intrinsic.sregName, MojoProof.Sem.Grid.start, MojoProof.Sem.Grid.Step, MojoProof.Sem.Grid.Sound, MojoProof.Sem.Kernel.Sound
corpus: none
tests: MojoProofTest.Launch, MojoProofTest.Start, MojoProofTest.SymLaunch, MojoProofTest.Gpu
upstream:
level: L3
evidence: L2: tests/gpu/naive/record.txt, tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt, tests/gpu/vsub/record.txt; L3: naive-matmul, vadd, vmul, vsub
---

# Threads and the launch

**The rule.** A launch has a grid of blocks of threads, both in three dimensions; every
thread runs the kernel with its own `tid`, `ntid`, `ctaid`, `nctaid` and lane id, read from
special registers.

**In Lean.** `MojoProof.Sem.Launch` is the grid and block shape and the dynamic shared memory
size; `Launch.Valid` bounds them; `Launch.env` gives each thread its registers (`Env.sreg`,
`Env.laneid`). `Grid.start` starts every thread, `Grid.Step` interleaves their steps over one
memory, and `Grid.Sound` (memory safety, race freedom and the rest) and `Kernel.Sound` (at one
launch) are what kernel theorems state, for the launches their premises admit.

**Tested against a GPU (L2).** A conformance test, not a proof. Each record is a run on one
A100 of a corpus kernel at several launches, and the grid evaluator (`Grid.start`, then
`Grid.run`, MojoProofTest.Gpu) on the same launch and inputs gives the same output buffer, bit
for bit, over the whole buffer: the words the threads write and the words no thread writes.

- tests/gpu/vadd/record.txt, tests/gpu/vmul/record.txt and tests/gpu/vsub/record.txt: six
  one-dimensional launches each, from one block of one thread to grids of 2 to 4 blocks of 16
  to 1024 threads, with more threads than words in some and fewer in one (1000 words, 512
  threads). The kernels read `tid.x`, `ntid.x` and `ctaid.x`.
- tests/gpu/naive/record.txt: eight two-dimensional launches of 1 x 1 to 2 x 3 blocks of 16 x
  16 threads, with threads outside the matrix in `x` and in `y`. The kernel reads `tid`,
  `ntid` and `ctaid` in `x` and `y`.

Each thread's output words are chosen by its registers, and the words no thread writes keep
their fill, so the agreement tests which threads the evaluator starts and the registers each
reads, at these launches. Not tested: `nctaid`, the lane id and the `z` registers (no kernel
of the records reads them), sides above 1 in `z`, and dynamic shared memory.

**Used by a proved kernel (L3).** The `Kernel.Sound` theorems of naive-matmul, vadd, vmul and
vsub are stated over `Grid.start` and `Grid.Step`, for every launch their premises admit
(STATUS.md gives the launches each admits).

**Out of scope.** Clusters, cooperative launches, and the scheduling guarantees of the
hardware beyond the interleaving.

**Open.** The construct ladder's top level. Ref: the section number and the quote are to be
added (quote to be added) from a local copy of the PTX ISA.
