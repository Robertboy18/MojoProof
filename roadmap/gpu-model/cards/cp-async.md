---
id: cp-async
title: cp.async, asynchronous copies from global to shared memory and their groups
kind: construct
ref: PTX ISA 9.5 #9.7.10.28.3.2
quote: ""
lean: MojoProof.Sem.AsyncCopy, MojoProof.Sem.AsyncCopy.Writes, MojoProof.Sem.AsyncOp, MojoProof.Sem.Async, MojoProof.Sem.Async.Step, MojoProof.Sem.Async.Run, MojoProof.Sem.Async.lazyRun, MojoProof.Sem.Async.Run.lazy, MojoProof.Sem.Async.Run.within, MojoProof.Sem.Async.lazyRun_init, MojoProof.Sem.Async.wait_run, MojoProof.Sem.Async.visible, MojoProof.Sem.Async.determined, MojoProof.Sem.Async.visible_bytes
corpus: none
tests: MojoProofTest.Async.wait1, MojoProofTest.Async.wait1_run, MojoProofTest.Async.wait0, MojoProofTest.Async.bytes, MojoProofTest.Async.boundary, MojoProofTest.Async.own, MojoProofTest.Async.reused, MojoProofTest.Async.overlap, MojoProofTest.AsyncGpu.wait0_bytes, MojoProofTest.AsyncGpu.wait1_bytes, MojoProofTest.AsyncGpu.wait1_pending
upstream:
depends: shared-memory
level: L1
---

# cp.async

**The rule.** `cp.async` starts a copy from global to shared memory that completes at some
later time; `cp.async.commit_group` closes the current group of copies and
`cp.async.wait_group n` waits until at most `n` groups are pending (sections 9.7.10.28.3.1 to
9.7.10.28.3.3).

**In Lean.** One thread's copies, commits and waits as a transition relation
(`MojoProof.Sem.Async.Step`) whose runs (`MojoProof.Sem.Async.Run`) land each pending copy at any
step, committed or not, and let `wait_group n` proceed once the groups other than the `n` most
recent have landed. For every sequence of operations and every completion choice: after
`wait_group n` at most `n` groups are pending (`MojoProof.Sem.Async.wait_run`); after
`wait_group 0` every copy committed before it has landed (`MojoProof.Sem.Async.visible`); a
shared byte that no possibly pending copy writes has the same value in every run
(`MojoProof.Sem.Async.determined`); and the landed bytes are the copies' sources, zero past
`src-size`, when the issued copies' destinations are disjoint
(`MojoProof.Sem.Async.visible_bytes`). Race freedom of the destinations and sources while a copy
is pending is the caller's premise. In the grid, the commit and wait intrinsics still run as
no-ops (`MojoProof.Sem.intrinsic`), sound only because no copy can be in flight: the copies come
as inline asm `cp.async.cg.shared.global`, which the importer accepts (MojoProof/LLVM/Asm.lean)
and exec refuses with a fault.

**On a GPU.** tests/gpu/cp-async/record.txt, a conformance test and not a proof: on an A100, 6
launches of one warp, each lane issuing 4 copies of 16 bytes into its own shared bytes, with
random sources and source sizes 0 to 16, in 3 groups; every shared word read back after
`wait_group 1` (the two older groups) and after `wait_group 0` is the model's
(`MojoProof.Sem.Async.smem` after `MojoProof.Sem.Async.lazyRun`), and after either wait every
run of the model gives it (`MojoProofTest.AsyncGpu.wait1_bytes`,
`MojoProofTest.AsyncGpu.wait0_bytes`). The run reads no byte a pending copy may write, so it
does not test when copies land.

**Out of scope.** `cp.async.bulk`, the mbarrier-based completion, and the cache hints.

**Open.** exec's copies and the grid's per-thread state. L2: the recorded GPU run agrees, but
it ran a driver of the instruction, not a corpus kernel, and the level counts only records of
corpus kernels. L3: no proved kernel uses it. Ref: quote to be added.
