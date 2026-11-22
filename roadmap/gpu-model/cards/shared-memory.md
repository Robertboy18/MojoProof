---
id: shared-memory
title: shared memory, the static and dynamic shared blocks of a block of threads
kind: construct
ref: PTX ISA 9.5 #shared-state-space
quote: ""
lean: MojoProof.Sem.shared, MojoProof.Sem.shared_blocks, MojoProof.Sem.shared_closed, MojoProof.Sem.Launch.dynShared, MojoProof.Sym.shared_res
corpus: none
tests: MojoProofTest.Eval, MojoProofTest.ScheduleOwned
upstream:
depends: address-spaces, launch
level: L1
---

# Shared memory

**The rule.** Each block of threads has its own shared memory: the module's shared globals
and, if the launch asks for it, a dynamic block. Its threads share it; other blocks do not see it.

**In Lean.** `MojoProof.Sem.shared` allocates a block of threads' shared globals and dynamic
block (`Launch.dynShared` bytes); `shared_blocks` and `shared_closed` keep the memory's
invariants. An `external constant` shared global is refused.

**Open.** L2: no recorded GPU run. L3: no proved kernel uses shared memory yet (the reduction
and the tiled matmul do). Ref: quote to be added.
