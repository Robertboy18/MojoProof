---
id: cp-async
title: cp.async, asynchronous copies from global to shared memory and their groups
kind: construct
ref: PTX ISA 9.5 #9.7.10.28.3.2
quote: ""
lean: MojoProof.Sem.AsyncCopy, MojoProof.Sem.AsyncOp, MojoProof.Sem.Async, MojoProof.Sem.Async.step, MojoProof.Sem.Async.wait_length, MojoProof.Sem.Async.run_init, MojoProof.Sem.Async.wait_run, MojoProof.Sem.Async.visible, MojoProof.Sem.Async.visible_bytes
corpus: none
tests: MojoProofTest.Async.wait1, MojoProofTest.Async.wait0, MojoProofTest.Async.bytes, MojoProofTest.Async.bytes_twin, MojoProofTest.Async.overlap
upstream:
depends: shared-memory
level: L1
---

# cp.async

**The rule.** `cp.async` starts a copy from global to shared memory that completes later;
`cp.async.commit_group` closes the current group of copies and `cp.async.wait_group n` waits
until at most `n` groups are pending (sections 9.7.10.28.3.1 to 9.7.10.28.3.3).

**In Lean.** One thread's copies, commits and waits as a state (`MojoProof.Sem.Async`): after
`wait_group n` at most `n` groups are pending (`MojoProof.Sem.Async.wait_length`), and after
`wait_group 0` every copy committed before it has landed, in order, and the copies issued after
the last commit have not (`MojoProof.Sem.Async.visible`), for every sequence of operations; the
landed bytes are the copies' sources, zero past `src-size`, when the committed destinations are
disjoint (`MojoProof.Sem.Async.visible_bytes`). Race freedom of the destinations and sources while
a copy is pending is the caller's premise. In the grid, the commit and wait intrinsics still run
as no-ops (`MojoProof.Sem.intrinsic`), sound only because no copy can be in flight: the copies
come as inline asm `cp.async.cg.shared.global`, which the importer accepts
(MojoProof/LLVM/Asm.lean) and exec refuses with a fault.

**Out of scope.** `cp.async.bulk`, the mbarrier-based completion, and the cache hints.

**Open.** exec's copies and the grid's per-thread state. L2: no recorded GPU run. L3: no
proved kernel uses it. Ref: quote to be added.
