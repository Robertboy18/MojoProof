---
id: barriers
title: the block barrier, bar.sync over the threads of a block
kind: construct
ref: PTX ISA 9.5 #9.7.15.1
quote: ""
lean: MojoProof.Sem.phases, MojoProof.Sem.phases_barrier, MojoProof.LLVM.Intrinsic.barrier_args, MojoProof.Sym.Seg.sound
corpus: none
tests: MojoProofTest.Launch.barrierDecl, MojoProofTest.Pending.atBarrier, MojoProofTest.Phased, MojoProofTest.SymSeg.gevm_segments
upstream:
depends: launch
level: L1
---

# The barrier

**The rule.** `llvm.nvvm.barrier.cta.sync.aligned.all` waits until every thread of the block
has reached it, and orders the memory accesses before it before those after it.

**In Lean.** The grid fires a block's barrier when all its threads wait at it; the trace
records it, and race freedom uses the happens-before of program order and the barriers
(`MojoProof.Sem.phases`, `phases_barrier`). The block checker's summary of a block stops at a
barrier call; the statements up to it are a segment (`summarizeTo`), and a thread's steps over
a segment reach the barrier's wait (`MojoProof.Sym.Seg.sound`, for every program; tested at
`gevm_kernel`'s reduction). No schedule through a barrier is proved, so no kernel theorem covers
a kernel with one yet.

**Out of scope.** Barriers that only some threads of the block reach (undefined behavior in
the semantics, stricter than PTX when threads have exited), and `bar.arrive`.

**Open.** L2: no recorded GPU run. L3: no proved kernel has a barrier. Ref: the section is the
one docs/TRUST.md cites; quote to be added.
