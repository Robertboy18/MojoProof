---
id: launch
title: threads and the launch, the grid and blocks of threads and their special registers
kind: construct
ref: PTX ISA 9.5 #special-registers
quote: ""
lean: MojoProof.Sem.Launch, MojoProof.Sem.Launch.Valid, MojoProof.Sem.Launch.env, MojoProof.Sem.Env.sreg, MojoProof.Sem.Env.laneid, MojoProof.LLVM.SReg, MojoProof.LLVM.Intrinsic.sregName, MojoProof.Sem.Grid.start, MojoProof.Sem.Grid.Step, MojoProof.Sem.Grid.Sound, MojoProof.Sem.Kernel.Sound
corpus: none
tests: MojoProofTest.Launch, MojoProofTest.Start, MojoProofTest.SymLaunch
upstream:
level: L1
evidence: L3: vadd, vmul
---

# Threads and the launch

**The rule.** A launch has a grid of blocks of threads, both in three dimensions; every
thread runs the kernel with its own `tid`, `ntid`, `ctaid`, `nctaid` and lane id, read from
special registers.

**In Lean.** `MojoProof.Sem.Launch` is the grid and block shape and the dynamic shared memory
size; `Launch.Valid` bounds them; `Launch.env` gives each thread its registers (`Env.sreg`,
`Env.laneid`). `Grid.start` starts every thread, `Grid.Step` interleaves their steps over one
memory, and `Grid.Sound` (memory safety, race freedom and the rest) and `Kernel.Sound` (for
every valid launch) are what kernel theorems state.

**Out of scope.** Clusters, cooperative launches, and the scheduling guarantees of the
hardware beyond the interleaving.

**Open.** L2: no recorded GPU run of a test of the launch. Ref: the section number and the
quote are to be added (quote to be added) from a local copy of the PTX ISA.
