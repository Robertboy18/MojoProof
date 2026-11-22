---
id: cp-async
title: cp.async, asynchronous copies from global to shared memory and their groups
kind: construct
ref: PTX ISA 9.5 #9.7.10.28.3.2
quote: ""
lean: not stated yet
corpus: none
tests: none
upstream:
depends: shared-memory
level: L0
---

# cp.async

**The rule.** `cp.async` starts a copy from global to shared memory that completes later;
`cp.async.commit_group` closes the current group of copies and `cp.async.wait_group n` waits
until at most `n` groups are pending.

**In the code.** The commit and wait intrinsics run as no-ops (`MojoProof.Sem.intrinsic`), which
is sound only because no copy can be in flight: the copies come as inline asm
`cp.async.cg.shared.global`, which the importer refuses (every multistage GEMM file of the
corpus). So the copies are not modelled.

**Open.** L1: the copies, pending until their group's wait. Ref: quote to be added.
